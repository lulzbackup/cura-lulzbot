# Copyright (c) 2016 Ultimaker B.V.
# Cura is released under the terms of the AGPLv3 or higher.

from .avr_isp import stk500v2, ispBase, intelHex
import serial   # type: ignore
import threading
import time
import queue
import re
import functools

from enum import Enum

from UM.Application import Application
from UM.Logger import Logger
from cura.PrinterOutputDevice import PrinterOutputDevice, ConnectionState
from UM.Message import Message
from UM.Preferences import Preferences

from PyQt5.QtWidgets import QMessageBox
from PyQt5.QtCore import QUrl, pyqtSlot, pyqtSignal, pyqtProperty

from .MarlinSerialProtocol import MarlinSerialProtocol

from UM.i18n import i18nCatalog
catalog = i18nCatalog("cura")

class Error(Enum):
    SUCCESS = 0
    PRINTER_BUSY = 1
    PRINTER_NOT_CONNECTED = 2

class USBPrinterOutputDevice(PrinterOutputDevice):
    SERIAL_AUTODETECT_PORT = "Autodetect"

    def __init__(self, serial_port):
        super().__init__(serial_port)
        self.setName(catalog.i18nc("@item:inmenu", "USB printing"))
        self.setShortDescription(catalog.i18nc("@action:button Preceded by 'Ready to'.", "Print via USB"))
        self.setDescription(catalog.i18nc("@info:tooltip", "Print via USB"))
        self.setIconName("print")
        self.eeprom_update = False
        self._autodetect_port = (serial_port == USBPrinterOutputDevice.SERIAL_AUTODETECT_PORT)
        if self._autodetect_port:
            serial_port = None
            self.setConnectionText(catalog.i18nc("@info:status", "USB device available"))
        else:
            self.setConnectionText(catalog.i18nc("@info:status", "Connect to %s" % serial_port))

        self._serial = None
        self._serial_port = serial_port
        self._error_state = None

        self._end_stop_thread = None
        self._poll_endstop = False

        self._connect_thread         = ConnectThread(self)
        self._print_thread           = PrintThread(self)
        self._update_firmware_thread = UpdateFirmwareThread(self)

        self._is_printing = False
        self._is_paused = False

        # Check if endstops are ever pressed (used for first run)
        self._x_min_endstop_pressed = False
        self._y_min_endstop_pressed = False
        self._z_min_endstop_pressed = False

        self._x_max_endstop_pressed = False
        self._y_max_endstop_pressed = False
        self._z_max_endstop_pressed = False

        self._error_message = None
        self._error_code = 0

    onError = pyqtSignal()

    firmwareUpdateComplete = pyqtSignal()
    firmwareUpdateChange = pyqtSignal()

    endstopStateChanged = pyqtSignal(str ,bool, arguments = ["key","state"])

    def _setTargetBedTemperature(self, temperature):
        Logger.log("d", "Setting bed temperature to %s", temperature)
        self.sendCommand("M140 S%s" % temperature)

    def _setTargetHotendTemperature(self, index, temperature):
        if index == -1:
            index = self._current_hotend
        Logger.log("d", "Setting hotend %s temperature to %s", index, temperature)
        self.sendCommand("M104 T%s S%s" % (index, temperature))

    def _setTargetHotendTemperatureAndWait(self, index, temperature):
        if index == -1:
            index = self._current_hotend
        Logger.log("d", "Setting hotend %s temperature to %s", index, temperature)
        self.sendCommand("M109 T%s S%s" % (index, temperature))

    def _setHeadPosition(self, x, y , z, speed):
        self.sendCommand("G0 X%s Y%s Z%s F%s" % (x, y, z, speed))

    def _setHeadX(self, x, speed):
        self.sendCommand("G0 X%s F%s" % (x, speed))

    def _setHeadY(self, y, speed):
        self.sendCommand("G0 Y%s F%s" % (y, speed))

    def _setHeadZ(self, z, speed):
        self.sendCommand("G0 Z%s F%s" % (z, speed))

    def _homeHead(self):
        self.sendCommand("G28")

    def _homeX(self):
        self.sendCommand("G28 X")

    def _homeY(self):
        self.sendCommand("G28 Y")

    def _homeBed(self):
        self.sendCommand("G28 Z")

    def _homeXY(self):
        self.sendCommand("G28 XY")

    ##  A name for the device.
    @pyqtProperty(str, constant = True)
    def name(self):
        return self.getName()

    ##  The address of the device.
    @pyqtProperty(str, constant = True)
    def address(self):
        return self._serial_port

    def startPrint(self):
        self.writeStarted.emit(self)
        gcode_list = getattr( Application.getInstance().getController().getScene(), "gcode_list")
        self._updateJobState("printing")
        self.printGCode(gcode_list)

    def _wipeNozzle(self):
        code = Application.getInstance().getGlobalContainerStack().getProperty("machine_wipe_gcode", "value")
        if not code or len(code) == 0:
            Logger.log("w", "This device doesn't support wiping")
            QMessageBox.critical(None, "Error wiping nozzle", "This device doesn't support wiping" )
            return
        code = code.replace("{material_wipe_temperature}", str(Application.getInstance().getGlobalContainerStack().getProperty("material_wipe_temperature", "value"))).split("\n")
        self.writeStarted.emit(self)
        self._updateJobState("printing")
        result=self.printGCode(code)

        if result == Error.PRINTER_BUSY:
            QMessageBox.critical(None, "Error wiping nozzle", "Printer is busy, aborting print" )

        if result == Error.PRINTER_NOT_CONNECTED:
            QMessageBox.critical(None, "Error wiping nozzle", "Printer is not connected  " )

    def _moveHead(self, x, y, z, speed):
        self.sendCommand("G91")
        self.sendCommand("G0 X%s Y%s Z%s F%s" % (x, y, z, speed))
        self.sendCommand("G90")

    def _extrude(self, e, speed):
        self.sendCommand("G91")
        self.sendCommand("G0 E%s F%s" % (e, speed))
        self.sendCommand("G90")

    def _setHotend(self, num):
        self.sendCommand("T%i" % num)

    def _setZOffset(self, zOffset, saveEEPROM):
        self.sendCommand("M851 Z%s" % (zOffset))
        if saveEEPROM == True:
            self.sendCommand("M500")


    def _getZOffset(self):
        self.sendCommand("M851")
        return self._ZOffset

    ##  Start a print based on a g-code.
    #   \param gcode_list List with gcode (strings).
    def printGCode(self, gcode_list):
        result = Error.SUCCESS

        Logger.log("d", "Started printing g-code")
        if self._progress:
            self._error_message = Message(catalog.i18nc("@info:status", "Unable to start a new job because the printer is busy."))
            self._error_message.show()
            Logger.log("d", "Printer is busy, aborting print")
            self.writeError.emit(self)
            result = Error.PRINTER_BUSY
            return result

        if self._connection_state != ConnectionState.connected:
            self._error_message = Message(catalog.i18nc("@info:status", "Unable to start a new job because the printer is not connected."))
            self._error_message.show()
            Logger.log("d", "Printer is not connected, aborting print")
            self.writeError.emit(self)
            result = Error.PRINTER_NOT_CONNECTED
            return result

        self._print_thread.printGCode(gcode_list)

        self.setTimeTotal(0)
        self.setTimeElapsed(0)
        self._printingStarted()

        self.writeFinished.emit(self)
        # Returning Error.SUCCESS here, currently is unused
        return result

    ## Called when print is starting
    def _printingStarted(self):
        Application.getInstance().preventComputerFromSleeping(True)
        self._is_printing = True

    ## Called when print is finished or cancelled
    def _printingStopped(self):
        Application.getInstance().preventComputerFromSleeping(False)
        self._is_printing = False
        self._is_paused = False
        self._updateJobState("ready")
        self.setTimeElapsed(0)
        self.setTimeTotal(0)

    ##  Get the serial port string of this connection.
    #   \return serial port
    def getSerialPort(self):
        return self._serial_port

    ##  Try to connect the serial. This simply starts the thread, which runs _connect.
    @pyqtSlot()
    def _connect(self):
        if not self._update_firmware_thread._updating_firmware and not self._connect_thread.isAlive() and self._connection_state in [ConnectionState.closed, ConnectionState.error]:
            self._connect_thread.start()

    ##  Upload new firmware to machine
    #   \param filename full path of firmware file to be uploaded
    def updateFirmware(self, file_name, eeprom_upd):
        if self._autodetect_port:
            self._detectSerialPort()
        self._update_firmware_thread.startFirmwareUpdate(file_name)
        self.eeprom_update = eeprom_upd

    @property
    def firmwareUpdateFinished(self):
        return self._update_firmware_thread._firmware_update_finished

    def resetFirmwareUpdate(self):
        self._update_firmware_thread._firmware_update_finished = False
        self.firmwareUpdateChange.emit()

    @pyqtSlot()
    def startPollEndstop(self):
        if not self._poll_endstop:
            self._poll_endstop = True
            if self._end_stop_thread is None:
                self._end_stop_thread = threading.Thread(target=self._pollEndStop)
                self._end_stop_thread.daemon = True
            self._end_stop_thread.start()

    @pyqtSlot()
    def stopPollEndstop(self):
        self._poll_endstop = False
        self._end_stop_thread = None

    def _pollEndStop(self):
        while self._connection_state == ConnectionState.connected and self._poll_endstop:
            self.sendCommand("M119")
            time.sleep(0.5)

    def _detectSerialPort(self):
        # Deferred import due to circular dependency
        from .USBPrinterOutputDeviceManager import USBPrinterOutputDeviceManager

        ports = USBPrinterOutputDeviceManager.getSerialPortList(True)
        for port in ports:
            programmer = stk500v2.Stk500v2()
            try:
                programmer.connect(port) # Connect with the serial, if this succeeds, it's an arduino based usb device.
                programmer.close()
                self._serial_port = port
                break
            except ispBase.IspError as e:
                Logger.log("i", "Could not establish connection on %s: %s. Device is not arduino based." %(port,str(e)))
            except Exception as e:
                Logger.log("i", "Could not establish connection on %s, unknown reasons.  Device is not arduino based." % port)

    ##  Set the baud rate of the serial. This can cause exceptions, but we simply want to ignore those.
    def setBaudRate(self, baud_rate):
        try:
            self._serial.baudrate = baud_rate
            return True
        except Exception as e:
            return False

    ##  Close the printer connection
    def _close(self):
        Logger.log("d", "Closing the USB printer connection.")
        self._printingStopped()
        self._connect_thread.wrapup()
        self._connect_thread = ConnectThread(self)

        self.setConnectionState(ConnectionState.closed)
        self.setConnectionText(catalog.i18nc("@info:status", "Connection closed"))
        if self._serial is not None:
            try:
                self._print_thread.join()
            except:
                pass
            self._serial.close()

        self._print_thread = PrintThread(self)
        self._serial = None
        self._serial_port = None
        self._is_printing = False
        self._is_paused = False

    ##  Send a command to printer.
    #   \param cmd string with g-code
    @pyqtSlot(str)
    def sendCommand(self, cmd):
        self._print_thread.sendCommand(cmd)

    ##  Set the error state with a message.
    #   \param error String with the error message.
    def _setErrorState(self, error):
        self._updateJobState("error")
        self._error_state = error
        self.onError.emit()

    ##  Request the current scene to be sent to a USB-connected printer.
    #
    #   \param nodes A collection of scene nodes to send. This is ignored.
    #   \param file_name \type{string} A suggestion for a file name to write.
    #   This is ignored.
    #   \param filter_by_machine Whether to filter MIME types by machine. This
    #   is ignored.
    #   \param kwargs Keyword arguments.
    def requestWrite(self, nodes, file_name = None, filter_by_machine = False, file_handler = None, **kwargs):
        container_stack = Application.getInstance().getGlobalContainerStack()
        if container_stack.getProperty("machine_gcode_flavor", "value") == "UltiGCode":
            self._error_message = Message(catalog.i18nc("@info:status", "This printer does not support USB printing because it uses UltiGCode flavor."))
            self._error_message.show()
            return
        elif not container_stack.getMetaDataEntry("supports_usb_connection"):
            self._error_message = Message(catalog.i18nc("@info:status", "Unable to start a new job because the printer does not support usb printing."))
            self._error_message.show()
            return

        Application.getInstance().showPrintMonitor.emit(True)
        if self._connection_state == ConnectionState.connected:
            self.startPrint()
        elif self._connection_state == ConnectionState.closed:
            self.close()
            self._connect_thread.setAutoStartOnConnect(True)
            self.connect()
        else:
            self._connect_thread.setAutoStartOnConnect(True)

    def _setEndstopState(self, endstop_key, value):
        if endstop_key == b"x_min":
            if self._x_min_endstop_pressed != value:
                self.endstopStateChanged.emit("x_min", value)
            self._x_min_endstop_pressed = value
        elif endstop_key == b"y_min":
            if self._y_min_endstop_pressed != value:
                self.endstopStateChanged.emit("y_min", value)
            self._y_min_endstop_pressed = value
        elif endstop_key == b"z_min":
            if self._z_min_endstop_pressed != value:
                self.endstopStateChanged.emit("z_min", value)
            self._z_min_endstop_pressed = value

    messageFromPrinter = pyqtSignal(str)
    errorFromPrinter = pyqtSignal(str)

    ##  Set the state of the print.
    #   Sent from the print monitor
    def _setJobState(self, job_state):
        if job_state == "pause":
            self._pausePrint()
        elif job_state == "print":
            self._resumePrint()
        elif job_state == "abort":
            self.cancelPrint()

    def _pausePrint(self):
        if not self._is_printing or self._is_paused:
            return

        settings = Application.getInstance().getGlobalContainerStack()
        machine_width  = settings.getProperty("machine_width",     "value")
        machine_depth  = settings.getProperty("machine_depth",     "value")
        machine_height = settings.getProperty("machine_height",    "value")
        retract_amount = settings.getProperty("retraction_amount", "value")

        self._print_thread.pause(machine_width, machine_depth, machine_height, retract_amount)

        self._is_paused = True
        self._updateJobState("paused")

        Logger.log("d", "Pausing print")

    def _resumePrint(self):
        if not self._is_printing or not self._is_paused:
            return

        self._print_thread.resume()

        self._is_paused = False
        self._updateJobState("printing")

    ##  Set the progress of the print.
    #   It will be normalized (based on max_progress) to range 0 - 100
    def setProgress(self, progress, max_progress = 100):
        self._progress = (progress / max_progress) * 100  # Convert to scale of 0-100
        if self._progress == 100:
            # Printing is done, reset progress
            self.setProgress(0)
            self._printingStopped()
        self.progressChanged.emit()

    ##  Cancel the current print. Printer connection wil continue to listen.
    def cancelPrint(self):
        Logger.log("i", "Cancelling print")

        # Stop print
        self._printingStopped()

        self.setProgress(0)
        self._print_thread.cancelPrint()

        # Lift and park nozzle, the pause routine can do this for us
        settings = Application.getInstance().getGlobalContainerStack()
        machine_width  = settings.getProperty("machine_width",     "value")
        machine_depth  = settings.getProperty("machine_depth",     "value")
        machine_height = settings.getProperty("machine_height",    "value")
        self._print_thread.pause(machine_width, machine_depth, machine_height, 0)

        # Turn off temperatures, fan and steppers
        self.sendCommand("M140 S0")
        self.sendCommand("M104 S0")
        self.sendCommand("M107")
        self.sendCommand("M84")
        Application.getInstance().showPrintMonitor.emit(False)

    ##  Check if the process did not encounter an error yet.
    def hasError(self):
        return self._error_state is not None

    ##  Pre-heats the heated bed of the printer, if it has one.
    #
    #   \param temperature The temperature to heat the bed to, in degrees
    #   Celsius.
    #   \param duration How long the bed should stay warm, in seconds. This is
    #   ignored because there is no g-code to set this.
    @pyqtSlot(float, float)
    def preheatBed(self, temperature, duration):
        Logger.log("i", "Pre-heating the bed to %i degrees.", temperature)
        self._setTargetBedTemperature(temperature)
        self.preheatBedRemainingTimeChanged.emit()

    ##  Cancels pre-heating the heated bed of the printer.
    #
    #   If the bed is not pre-heated, nothing happens.
    @pyqtSlot()
    def cancelPreheatBed(self):
        Logger.log("i", "Cancelling pre-heating of the bed.")
        self._setTargetBedTemperature(0)
        self.preheatBedRemainingTimeChanged.emit()

#################################################################################
#                               ConnectThread                                   #
#################################################################################
class ConnectThread:
    def __init__(self, parent):
        # TODO: Any access to the parent object from the ConnectThread is
        # potentially not thread-safe and ought to be reviewed at some point.
        self._parent = parent

        self._thread = threading.Thread(target = self._connect_func)
        self._thread.daemon = True

        self._write_requested = False

        # The baud checking is done by sending a number of m105 commands to the printer and waiting for a readable
        # response. If the baudrate is correct, this should make sense, else we get giberish.
        self._required_responses_auto_baud = 3

    def start(self):
        return  self._thread.start()

    def isAlive(self):
        return  self._thread.isAlive()

    def wrapup(self):
        if self._thread.isAlive():
            try:
                # TODO: to avoid waiting indefinitely, notify the thread that it needs
                # to return immediatly.
                self._thread.join()
            except Exception as e:
                Logger.log("d", "PrinterConnection.close: %s (expected)", e)
                pass # This should work, but it does fail sometimes for some reason

    def setAutoStartOnConnect(self, value):
        self._write_requested = value

    ##  Create a list of baud rates at which we can communicate.
    #   \return list of int
    def _getBaudrateList(self):
        ret = [115200, 250000, 230400, 57600, 38400, 19200, 9600]
        return ret

    ##  private read line used by ConnectThread to listen for data on serial port.
    def _readline(self):
        if self._parent._serial is None:
            return None
        try:
            ret = self._parent._serial.readline()
        except Exception as e:
            Logger.log("e", "Unexpected error while reading serial port. %s" % e)
            self._parent._setErrorState("Printer has been disconnected")
            self._parent.close()
            return None
        return ret

    ##  Directly send the command, withouth checking connection state (eg; printing).
    #   \param cmd string with g-code
    def _sendCommand(self, cmd):
        if self._parent._serial is None:
            return

        try:
            command = (cmd + "\n").encode()
            self._parent._serial.write(b"\n")
            self._parent._serial.write(command)
        except serial.SerialTimeoutException:
            Logger.log("w","Serial timeout while writing to serial port, trying again.")
            try:
                time.sleep(0.5)
                self._parent._serial.write((cmd + "\n").encode())
            except Exception as e:
                Logger.log("e","Unexpected error while writing serial port %s " % e)
                self._parent._setErrorState("Unexpected error while writing serial port %s " % e)
                self._parent.close()
        except Exception as e:
            Logger.log("e","Unexpected error while writing serial port %s" % e)
            self._parent._setErrorState("Unexpected error while writing serial port %s " % e)
            self._parent.close()

    ##  Private connect function run by thread. Can be started by calling connect.
    def _connect_func(self):
        port = Application.getInstance().getGlobalContainerStack().getProperty("machine_port", "value")
        if port != "AUTO":
            self._parent._serial_port = port
            self._parent._autodetect_port = False

        Logger.log("d", "Attempting to connect to %s", self._parent._serial_port)
        self._parent.setConnectionState(ConnectionState.connecting)

        if self._parent._autodetect_port:
            self._parent.setConnectionText(catalog.i18nc("@info:status", "Scanning available serial ports for printers"))
            self._parent._detectSerialPort()
            if self._parent._serial_port == None:
                self._parent.setConnectionText(catalog.i18nc("@info:status", "Failed to find a printer via USB"))
                return
        else:
            self._parent.setConnectionText(catalog.i18nc("@info:status", "Connecting to USB device"))
        programmer = stk500v2.Stk500v2()
        try:
            programmer.connect(self._parent._serial_port) # Connect with the serial, if this succeeds, it's an arduino based usb device.
            self._parent._serial = programmer.leaveISP()
        except ispBase.IspError as e:
            programmer.close()
            Logger.log("i", "Could not establish connection on %s: %s. Device is not arduino based." %(self._parent._serial_port,str(e)))
        except Exception as e:
            programmer.close()
            Logger.log("i", "Could not establish connection on %s, unknown reasons.  Device is not arduino based." % self._parent._serial_port)

        baud_rate = Application.getInstance().getGlobalContainerStack().getProperty("machine_baudrate", "value")
        if baud_rate != "AUTO":
            self._parent.setConnectionText(catalog.i18nc("@info:status", "Connecting"))
            Logger.log("d", "Attempting to connect to printer with serial %s on baud rate %s", self._parent._serial_port, baud_rate)
            if self._parent._serial is None:
                try:
                    self._parent._serial = serial.Serial(str(self._parent._serial_port), baud_rate, timeout=3, writeTimeout=10000)
                    time.sleep(10)
                except serial.SerialException:
                    Logger.log("d", "Could not open port %s" % self._parent._serial_port)
            else:
                self._parent.setBaudRate(baud_rate)

            time.sleep(1.5)
            timeout_time = time.time() + 5
            self._parent._serial.write(b"\n")
            self._sendCommand("M105")
            while timeout_time > time.time():
                line = self._readline()
                if line is None:
                    self._onNoResponseReceived()
                    return

                if b"T:" in line:
                    Logger.log("d", "Correct response for connection")
                    self._parent._serial.timeout = 2  # Reset serial timeout
                    self._onConnectionSucceeded()
                    return

        self._parent.setConnectionText(catalog.i18nc("@info:status", "Autodetecting Baudrate"))
        # If the programmer connected, we know its an atmega based version.
        # Not all that useful, but it does give some debugging information.
        for baud_rate in self._getBaudrateList(): # Cycle all baud rates (auto detect)
            Logger.log("d", "Attempting to connect to printer with serial %s on baud rate %s", self._parent._serial_port, baud_rate)
            if self._parent._serial is None:
                try:
                    self._parent._serial = serial.Serial(str(self._parent._serial_port), baud_rate, timeout = 3, writeTimeout = 10000)
                    time.sleep(10)
                except serial.SerialException:
                    Logger.log("d", "Could not open port %s" % self._parent._serial_port)
                    continue
            else:
                if not self._parent.setBaudRate(baud_rate):
                    continue  # Could not set the baud rate, go to the next

            time.sleep(1.5) # Ensure that we are not talking to the bootloader. 1.5 seconds seems to be the magic number
            sucesfull_responses = 0
            timeout_time = time.time() + 5
            self._parent._serial.write(b"\n")
            self._sendCommand("M105")  # Request temperature, as this should (if baudrate is correct) result in a command with "T:" in it
            while timeout_time > time.time():
                line = self._readline()
                if line is None:
                    _onNoResponseReceived()
                    return

                if b"T:" in line:
                    Logger.log("d", "Correct response for auto-baudrate detection received.")
                    self._parent._serial.timeout = 0.5
                    sucesfull_responses += 1
                    if sucesfull_responses >= self._required_responses_auto_baud:
                        self._parent._serial.timeout = 2 # Reset serial timeout
                        self._onConnectionSucceeded()
                        return

                self._sendCommand("M105")  # Send M105 as long as we are listening, otherwise we end up in an undefined state

        Logger.log("e", "Baud rate detection for %s failed", self._parent._serial_port)
        self._parent.close()  # Unable to connect, wrap up.
        self._parent.setConnectionState(ConnectionState.closed)
        self._parent.setConnectionText(catalog.i18nc("@info:status", "Baud rate detection failed"))
        self._parent._serial_port = None

    class CheckFirmwareStatus(Enum):
        OK = 0
        TIMEOUT = 1
        WRONG_MACHINE = 2
        WRONG_TOOLHEAD = 3
        FIRMWARE_OUTDATED = 4

    def _checkFirmware(self):
        self._sendCommand("\nM115")
        timeout = time.time() + 2
        reply = self._readline()
        while b"FIRMWARE_NAME" not in reply and time.time() < timeout:
            reply = self._readline()

        if b"FIRMWARE_NAME" not in reply:
            return self.CheckFirmwareStatus.TIMEOUT

        firmware_string = reply.decode()
        values = {m[0] : m[1] for m in re.findall("([A-Z_]+)\:(.*?)(?= [A-Z_]+\:|$)", firmware_string)}

        global_container_stack = Application.getInstance().getGlobalContainerStack()

        class CheckValueStatus(Enum):
            OK = 0
            MISSING_VALUE_IN_REPLY = 1
            WRONG_VALUE = 2
            MISSING_VALUE_IN_DEFINITION = 3

        def checkValue(fw_key, profile_key, exact_match = True, search_in_properties = False):
            expected_value = global_container_stack.getProperty(profile_key, "value") if search_in_properties else\
                global_container_stack.getMetaDataEntry(profile_key, None)
            if expected_value is None:
                Logger.log("d", "Missing %s in profile. Skipping check." % profile_key)
                return CheckValueStatus.MISSING_VALUE_IN_DEFINITION
            elif not fw_key in values:
                Logger.log("d", "Missing %s in firmware string: %s" % (fw_key, firmware_string))
                return CheckValueStatus.MISSING_VALUE_IN_REPLY
            elif exact_match and values[fw_key] != expected_value:
                Logger.log("e", "Expected that %s was %s, but got %s instead" % (fw_key, expected_value, values[fw_key]))
                return CheckValueStatus.WRONG_VALUE
            elif not exact_match and not values[fw_key].search(expected_value):
                Logger.log("e", "Expected that %s contained %s, but got %s instead" % (fw_key, expected_value, values[fw_key]))
                return CheckValueStatus.WRONG_VALUE
            return CheckValueStatus.OK

        list_to_check = [
            {
                "reply_key": "MACHINE_TYPE",
                "definition_key": "firmware_machine_type",
                "on_fail": self.CheckFirmwareStatus.WRONG_MACHINE,
                "search_in_properties": True
            },
            {
                "reply_key": "EXTRUDER_TYPE",
                "definition_key": "firmware_toolhead_name",
                "on_fail": self.CheckFirmwareStatus.WRONG_TOOLHEAD
            },
            {
                "reply_key": "FIRMWARE_VERSION",
                "definition_key": "firmware_last_version",
                "on_fail": self.CheckFirmwareStatus.FIRMWARE_OUTDATED
            }
        ]
        for option in list_to_check:
            result = checkValue(option["reply_key"], option["definition_key"], option.get("exact_match", True), option.get("search_in_properties", False))
            if result != CheckValueStatus.OK:
                if result == CheckValueStatus.MISSING_VALUE_IN_DEFINITION:
                    pass
                elif result == CheckValueStatus.MISSING_VALUE_IN_REPLY:
                    return self.CheckFirmwareStatus.FIRMWARE_OUTDATED
                else:
                    return option["on_fail"]

        return self.CheckFirmwareStatus.OK

    def _onNoResponseReceived(self):
        Logger.log("d", "No response from serial connection received.")
        # Something went wrong with reading, could be that close was called.
        self._parent.close()  # Unable to connect, wrap up.
        self._parent.setConnectionState(ConnectionState.closed)
        self._parent.setConnectionText(catalog.i18nc("@info:status", "Connection to USB device failed"))
        self._parent._serial_port = None

    def _onConnectionSucceeded(self):
        def showWarning(self, shortMsg, longMsg):
            Logger.log("d", shortMsg)
            self._parent._error_message = Message(catalog.i18nc("@info:status", longMsg), dismissable=True, lifetime=None)
            self._parent._error_message.show()
        check_firmware_status = self._checkFirmware()
        if check_firmware_status == self.CheckFirmwareStatus.FIRMWARE_OUTDATED:
            showWarning(self, "Installed firmware is outdated", "New printer firmware is available. Use \"Settings -> Printer -> Manage Printers... -> Upgrade Firmware\" to upgrade.")
        elif check_firmware_status == self.CheckFirmwareStatus.WRONG_MACHINE:
            allow_connecction = Preferences.getInstance().getValue("cura/allow_connection_to_wrong_machine")
            if not allow_connecction:
                showWarning(self, "Wrong machine detected.", "Wrong printer detected, starting a print with the incorrect printer selected may damage your printer. You can disable this check in application settings")
                self._parent.close()  # Unable to connect, wrap up.
                self._parent.setConnectionState(ConnectionState.closed)
                return
            else:
                showWarning(self, "Wrong machine detected.",
                            "Wrong printer detected, starting a print with the incorrect printer selected may damage your printer.")
        elif check_firmware_status == self.CheckFirmwareStatus.WRONG_TOOLHEAD:
            Logger.log("d", "Tried to connect to machine with wrong toolhead")
            showWarning(self, "Wrong toolhead detected.", "Wrong toolhead detected. Please change this if it is not what you want.")
            #self._parent.close()  # Unable to connect, wrap up.
            #self._parent.setConnectionState(ConnectionState.closed)
            Application.getInstance().getMachineManager().toolheadChanged.emit()
            #return
        elif check_firmware_status == self.CheckFirmwareStatus.TIMEOUT:
            showWarning(self, "Connection timeout.", "Failed to determine installed firmware version.")
        self._parent.setConnectionText(catalog.i18nc("@info:status", "Connected via USB"))
        self._parent.setConnectionState(ConnectionState.connected)

        if self._parent.eeprom_update:
            self._sendCommand("M502")
            self._sendCommand("M500")
            Logger.log("d", "Tried to update EEPROM")
            self._parent.eeprom_update = False

        self._parent._print_thread.start()  # Start listening
        Logger.log("i", "Established printer connection on port %s" % self._parent._serial_port)
        if check_firmware_status == self.CheckFirmwareStatus.OK:
            if self._write_requested:
                self._parent.startPrint()
            self._write_requested = False

#################################################################################
#                            UpdateFirmwareThread                               #
#################################################################################

class UpdateFirmwareThread:
    def __init__(self, parent):
        # TODO: Any access to the parent object from the UpdateFirmwareThread is
        # potentially not thread-safe and ought to be reviewed at some point.
        self._parent = parent

        self._thread = threading.Thread(target= self._update_firmware_func)
        self._thread.daemon = True
        self._parent.firmwareUpdateComplete.connect(self._onFirmwareUpdateComplete)

        self._updating_firmware = False

        self._firmware_file_name = None
        self._firmware_update_finished = False

    def startFirmwareUpdate(self, file_name):
        Logger.log("i", "Updating firmware of %s using %s", self._parent._serial_port, file_name)
        self._firmware_file_name = file_name
        self._thread.start()

    def _onFirmwareUpdateComplete(self):
        self._thread.join()
        self._thread = threading.Thread(target = self._update_firmware_func)
        self._thread.daemon = True

        self._parent.connect()


    ##  Private function (threaded) that actually uploads the firmware.
    def _update_firmware_func(self):
        Logger.log("d", "Attempting to update firmware")
        self._parent._error_code = 0
        self._parent.setProgress(0, 100)
        self._firmware_update_finished = False

        if self._parent._connection_state != ConnectionState.closed:
            self._parent.close()
        port = Application.getInstance().getGlobalContainerStack().getProperty("machine_port", "value")
        if port != "AUTO":
            self._parent._serial_port = port
        else:
            self._parent._detectSerialPort()

        try:
            hex_file = intelHex.readHex(self._firmware_file_name)
        except FileNotFoundError:
            Logger.log("e", "Unable to find hex file. Could not update firmware")
            self._updateFirmwareFailedMissingFirmware()
            return

        if len(hex_file) == 0:
            Logger.log("e", "Unable to read provided hex file. Could not update firmware")
            self._updateFirmwareFailedMissingFirmware()
            return

        programmer = stk500v2.Stk500v2()
        programmer.progress_callback = self._parent.setProgress

        try:
            programmer.connect(self._parent._serial_port)
        except Exception:
            programmer.close()
            pass

        # Give programmer some time to connect. Might need more in some cases, but this worked in all tested cases.
        time.sleep(1)

        if not programmer.isConnected():
            Logger.log("e", "Unable to connect with serial. Could not update firmware")
            self._updateFirmwareFailedCommunicationError()
            return

        self._updating_firmware = True

        try:
            programmer.programChip(hex_file)
            self._updating_firmware = False
        except serial.SerialException as e:
            Logger.log("e", "SerialException while trying to update firmware: <%s>" %(repr(e)))
            self._updateFirmwareFailedIOError()
            return
        except Exception as e:
            Logger.log("e", "Exception while trying to update firmware: <%s>" %(repr(e)))
            self._updateFirmwareFailedUnknown()
            return
        programmer.close()

        self._updateFirmwareCompletedSucessfully()
        self._parent._serial_port = None
        return

    ##  Private function which makes sure that firmware update process has failed by missing firmware
    def _updateFirmwareFailedMissingFirmware(self):
        return self._updateFirmwareFailedCommon(4)

    ##  Private function which makes sure that firmware update process has failed by an IO error
    def _updateFirmwareFailedIOError(self):
        return self._updateFirmwareFailedCommon(3)

    ##  Private function which makes sure that firmware update process has failed by a communication problem
    def _updateFirmwareFailedCommunicationError(self):
        return self._updateFirmwareFailedCommon(2)

    ##  Private function which makes sure that firmware update process has failed by an unknown error
    def _updateFirmwareFailedUnknown(self):
        return self._updateFirmwareFailedCommon(1)

    ##  Private common function which makes sure that firmware update process has completed/ended with a set progress state
    def _updateFirmwareFailedCommon(self, code):
        if not code:
            raise Exception("Error code not set!")

        self._parent._error_code = code

        self._firmware_update_finished = True
        self._parent.firmwareUpdateChange.emit()
        self._parent.progressChanged.emit()
        self._parent.firmwareUpdateComplete.emit()

        return

    ##  Private function which makes sure that firmware update process has successfully completed
    def _updateFirmwareCompletedSucessfully(self):
        self._parent.setProgress(100, 100)
        self._firmware_update_finished = True
        self._parent.firmwareUpdateChange.emit()
        self._parent.firmwareUpdateComplete.emit()

        return

#################################################################################
#                                 PrintThread                                   #
#################################################################################

class PrintThread:
    def __init__(self, parent):
        # TODO: Any access to the parent object from the PrintThread is
        # potentially not thread-safe and ought to be reviewed at some point.
        self._parent = parent

        # Queue for commands that are sent while a print is active.
        self._command_queue = queue.Queue()

        # List of gcode lines to be printed
        self._gcode = []
        self._gcode_position = 0

        # Information needed to restart a paused print
        self._pauseState = None

        # Set to True to flush MarlinSerialProtocol buffers in thread
        self._flushBuffers = False

        # Set when print is started in order to check running time.
        self._print_start_time = None
        self._backend_print_time = None

        # Lock object for syncronizing accesses to self._gcode and other
        # variables which are shared between the UI thread and the
        # _print_thread thread.
        self._mutex = threading.Lock()

        # Event for when commands are added to self._command_queue
        self._commandAvailable = threading.Event();

        # Create the thread object

        self._thread = threading.Thread(target=self._print_func)
        self._thread.daemon = True

    def start(self):
        self._thread.start()

    def join(self):
        self._thread.join()

    def printGCode(self, gcode_list):
        self._mutex.acquire();
        self._gcode.clear()
        for layer in gcode_list:
            self._gcode.extend(layer.strip("\n").split("\n"))
        self._gcode_position = 0
        self._print_start_time_100 = None
        self._print_start_time = time.time()
        self._flushBuffers = True
        self._pauseState = None
        self._mutex.release();

    def cancelPrint(self):
        self._mutex.acquire();
        self._gcode = []
        while not self._command_queue.empty():
            self._command_queue.get()
        self._gcode_position = 0
        self._flushBuffers = True
        self._pauseState = None
        self._mutex.release();

    def _isHeaterCommand(self, cmd):
        """Checks whether we have a M109 or M190"""
        return cmd.startswith("M109") or cmd.startswith("M190")

    def _isInfiniteWait(self, cmd):
        """Sending a heater command with a temperature of zero will lead to an infinite wait"""
        if self._isHeaterCommand(cmd):
            search = re.search("[RS](-?[0-9\.]+)", cmd)
            return True if search and int(search.group(1)) == 0 else False
        else:
            return False

    def _parseTemperature(self, line, label, current_setter, target_setter):
        """Marlin reports current and target temperatures as 'T0:100.00 /100.00'.
           This extracts the temps and calls setter functions with the values."""
        m = re.search(b"%s: *([0-9\.]*)(?: */([0-9\.]*))?" % label, line)
        try:
            if m and m.group(1):
                current_setter(float(m.group(1)))
            if m and m.group(2):
                target_setter(float(m.group(2)))
        except ValueError:
            pass

    def sendCommand(self, cmd):
        """Sends a command to the printer. This command will take
           precedence over commands that are being send via printGCode"""
        if self._isInfiniteWait(cmd):
            return
        self._command_queue.put(cmd)
        self._commandAvailable.set()

    def _print_func(self):
        Logger.log("i", "Printer connection listen thread started for %s" % self._parent._serial_port)

        self._backend_print_time = Application.getInstance().getPrintInformation().currentPrintTime.totalSeconds

        # Wrap a MarlinSerialProtocol object around the serial port
        # for serial error correction.
        def onResendCallback(line):
            Logger.log("i", "USBPrinterOutputDevice: Resending from: %d" % (line))
            self._parent.messageFromPrinter.emit("USBPrinterOutputDevice: Resending from: %d" % (line))
        serial_proto = MarlinSerialProtocol(self._parent._serial, onResendCallback)

        temperature_request_timeout = time.time()
        while self._parent._connection_state == ConnectionState.connected:

            self._mutex.acquire()
            if self._flushBuffers:
                serial_proto.sendCmdEmergency("M108")
                serial_proto.restart()
                self._flushBuffers = False

            isPrinting = (     self._parent._is_printing and
                           not self._parent._is_paused and
                               self._pauseState is None)
            self._mutex.release()

            try:
                # If we are printing, and Marlin can receive data, then send
                # the next line (unless there are immediate commands queued up)
                if serial_proto.clearToSend() and isPrinting and not self._commandAvailable.isSet():
                    line = self._getNextGcodeLine()
                    if line:
                        serial_proto.sendCmdReliable(line)

                # If we are printing, wait on data from the serial port;
                # otherwise wait for interactive commands when the serial
                # port is idle. This allows us to be most responsive to
                # whatever action is currently taking place
                line = serial_proto.readline(isPrinting)
                if isPrinting and self._gcode_position > 1 and re.search(b"start\n",line):
                    Logger.log("e", "The printer has restarted or lost power.")
                    self.cancelPrint()
                    self._parent._printingStopped()
                    self._parent.setProgress(0)
                    self._parent.close()
                    self._parent._error_message = Message(catalog.i18nc("@info:status", "The printer has restarted or lost power."), 0, True, None, 2)
                    self._parent._error_message.show()
                    break

                if ((not isPrinting and line == b"" and self._commandAvailable.wait(2)) or
                    (    isPrinting and self._commandAvailable.isSet())):
                    self._mutex.acquire()
                    cmd = self._command_queue.get()
                    if self._command_queue.empty():
                        self._commandAvailable.clear()
                    self._mutex.release()
                    serial_proto.sendCmdUnreliable(cmd)

            except Exception as e:
                Logger.log("e", "Unexpected error while accessing serial port. %s" % e)
                self._parent._setErrorState("Printer has been disconnected")
                self._parent.close()
                break

            if line is None:
                break  # None is only returned when something went wrong. Stop listening

            if b"PROBE FAIL CLEAN NOZZLE" in line:
               self._parent.errorFromPrinter.emit( "Wipe nozzle failed." )
               Logger.log("d", "---------------PROBE FAIL CLEAN NOZZLE" )
               self._parent._error_message = Message(catalog.i18nc("@info:status", "Wipe nozzle failed."))
               self._parent._error_message.show()
               self._parent.close()
               break

            if b"Z Offset " in line:
                value = line.split(b":")
                if len(value) == 3:
                    self._parent._ZOffset = float( value[2] )

            # If we keep getting a temperature_request_timeout, it likely
            # means that Marlin does not support AUTO_REPORT_TEMPERATURES,
            # in which case we must poll.
            if time.time() > temperature_request_timeout:
                Logger.log("d", "Requesting temperature auto-update")
                serial_proto.sendCmdUnreliable("M155 S3")
                serial_proto.sendCmdUnreliable("M105")
                temperature_request_timeout = time.time() + 5

            if line.startswith(b"Error:"):
                #if b"PROBE FAIL CLEAN NOZZLE" in line:
                #   self._error_message = Message(catalog.i18nc("@info:status", "Wipe nozzle failed."))
                #   self._error_message.show()
                #   QMessageBox.critical(None, "Error wiping nozzle", "Probe fail clean nozzle"

                # Oh YEAH, consistency.
                # Marlin reports a MIN/MAX temp error as "Error:x\n: Extruder switched off. MAXTEMP triggered !\n"
                # But a bed temp error is reported as "Error: Temperature heated bed switched off. MAXTEMP triggered !!"
                # So we can have an extra newline in the most common case. Awesome work people.
                if re.match(b"Error:[0-9]\n", line):
                    line = line.rstrip() + serial_proto.readline()

                # Skip the communication errors, as those get corrected.
                if b"Extruder switched off" in line or b"Temperature heated bed switched off" in line or b"Something is wrong, please turn off the printer." in line:
                    if not self._parent.hasError():
                        self._parent._setErrorState(line[6:])

            if b"_min" in line or b"_max" in line:
                tag, value = line.split(b":", 1)
                self._parent._setEndstopState(tag,(b"H" in value or b"TRIGGERED" in value))

            if b"T:" in line:
                temperature_request_timeout = time.time() + 5
                # We got a temperature report line. If we have a dual extruder,
                # Marlin reports temperatures independently as T0: and T1:,
                # otherwise look for T:. Bed temperatures will be reported as B:
                if b" T0:" in line and b" T1:" in line:
                    if self._parent._num_extruders != 2:
                        self._parent._num_extruders = 2
                        PrinterOutputDevice._setNumberOfExtruders(self._parent, self._parent._num_extruders)
                    self._parseTemperature(line, b"T0",
                        lambda x: self._parent._setHotendTemperature(0,x),
                        lambda x: self._parent._emitTargetHotendTemperatureChanged(0,x)
                    )
                    self._parseTemperature(line, b"T1",
                        lambda x: self._parent._setHotendTemperature(1,x),
                        lambda x: self._parent._emitTargetHotendTemperatureChanged(1,x)
                    )
                else:
                    if self._parent._num_extruders != 1:
                        self._parent._num_extruders = 1
                        PrinterOutputDevice._setNumberOfExtruders(self._parent, self._parent._num_extruders)
                    self._parseTemperature(line, b"T",
                        lambda x: self._parent._setHotendTemperature(0,x),
                        lambda x: self._parent._emitTargetHotendTemperatureChanged(0,x)
                    )
                if b"B:" in line:  # Check if it's a bed temperature
                    self._parseTemperature(line, b"B",
                        lambda x: self._parent._setBedTemperature(x),
                        lambda x: self._parent._emitTargetBedTemperatureChanged(x)
                    )

            if line not in [b"", b"ok\n"]:
                self._parent.messageFromPrinter.emit(line.decode("latin-1").replace("\n", ""))

        Logger.log("i", "Printer connection listen thread stopped for %s" % self._parent._serial_port)

    ##  Gets the next Gcode in the gcode list
    def _getNextGcodeLine(self):
        self._mutex.acquire();
        gcodeLen  = len(self._gcode)
        line = self._gcode[self._gcode_position]
        self._mutex.release();

        if self._gcode_position >= gcodeLen:
            return
        if self._gcode_position % 100 == 0:
            elapsed = time.time() - self._print_start_time
            progress = self._gcode_position / gcodeLen
            if progress > 0:
                total = elapsed + self._backend_print_time * (1 - progress)
                self._parent.setTimeTotal(total)
                self._parent.setTimeElapsed(elapsed)

        # Don't send the M0 or M1 to the machine, as M0 and M1 are handled as
        # an LCD menu pause.
        if re.match('\s*M[01]\\b', line):
            # Don't send the M0 or M1 to the machine, as M0 and M1 are handled as an LCD menu pause.
            Logger.log("d", "Encountered M0 or M1, pausing print" )
            self._parent._setJobState("pause")
            line = False

        self._gcode_position += 1
        self._parent.setProgress((self._gcode_position / gcodeLen) * 100)
        self._parent.progressChanged.emit()
        return line

    class PauseState:
        def __init__(self):
            self.x = None
            self.y = None
            self.z = None
            self.f = None
            self.e = None
            self.retraction = None

    def _findLastPosition(self):
        """Runs backwards through GCODE lines that were already sent until
        the last complete position is determined, return False otherwise"""
        pos = self.PauseState()
        axis_re = re.compile('([XYZEF])(-?[0-9\.]+)')
        self._mutex.acquire()
        for i in range(self._gcode_position - 1, 0, -1):
            line = self._gcode[i].upper()
            if ('G0' in line or 'G1' in line):
                for a, v in re.findall(axis_re, line):
                    if a == 'X' and pos.x is None:
                        pos.x = float(v)
                    if a == 'Y' and pos.y is None:
                        pos.y = float(v)
                    if a == 'Z' and pos.z is None:
                        pos.z = float(v)
                    if a == 'E' and pos.e is None:
                        pos.e = float(v)
                    if a == 'F' and pos.f is None:
                        pos.f = float(v)
                if (pos.x is not None and
                    pos.y is not None and
                    pos.z is not None and
                    pos.f is not None and
                    pos.e is not None):
                    break
        self._mutex.release()
        if pos.x is None or pos.y is None or pos.z is None:
            return None
        return pos

    def pause(self, machine_width, machine_depth, machine_height, retract_amount):
        """Pauses the print in progress, lifting the head, parking and retracting.
           Also used to park the head after a print stops."""
        parkX  = machine_width  - 10
        parkY  = machine_depth  - 10
        maxZ   = machine_height - 10
        raiseZ = 10.0

        # Prior to enqueuing the head motion commands, set
        # _pauseState as this will block the PrintThread.

        pos = self._findLastPosition()
        self._mutex.acquire()
        if pos:
            self._pauseState = pos
            self._pauseState.retraction = retract_amount
        else:
            # Pause with unknown position.
            self._pauseState = True
        self._mutex.release()

        if retract_amount > 0:
            # Set E relative positioning
            self.sendCommand("M83")

            # Retract the filament
            self.sendCommand("G1 E%f F120" % (-retract_amount))

            # Set E absolute positioning
            self.sendCommand("M82")

        # Move the toolhead up, if position is known
        if pos:
            parkZ = max(min(pos.z + raiseZ, maxZ), pos.z)
            self.sendCommand("G1 Z%f F3000" % parkZ)

        # Move the head away
        self.sendCommand("G1 X%f Y%f F9000" % (parkX, parkY))

        # Disable the E steppers
        self.sendCommand("M18 E")

    def resume(self):
        """Resumes a print that was paused"""
        if isinstance(self._pauseState, self.PauseState):
            pos = self._pauseState
            if pos.f is None:
                pos.f = 1200
            if pos.e is None:
                pos.e = 0

            if pos.retraction > 0:
                # Set E relative positioning
                self.sendCommand("M83")
                # Prime the nozzle when changing filament
                self.sendCommand("G1 E%f F120" %  pos.retraction)  # Push the filament out
                self.sendCommand("G1 E%f F120" % -pos.retraction)  # retract again
                # Prime the nozzle again
                self.sendCommand("G1 E%f F120" %  pos.retraction)
                # Set E absolute positioning
                self.sendCommand("M82")
                # Set E absolute position to cancel out any extrude/retract that occured
                self.sendCommand("G92 E%f" % pos.e)

            # Set proper feedrate
            self.sendCommand("G1 F%f" % pos.f)
            # Re-home the nozzle
            self.sendCommand("G28 X0 Y0")
            # Position the toolhead to the correct position and feedrate again
            self.sendCommand("G1 X%f Y%f Z%f F%f" % (pos.x, pos.y, pos.z, pos.f))
            Logger.log("d", "Print resumed")

            # Release the PrintThread.
            self._mutex.acquire()
            self._pauseState = None
            self._mutex.release()
