"""
NeoChucao — ui.py
Pre-launch device selection dialog (output audio + MIDI input).
Runs before scsynth boots; selections are passed into server.boot() and MidiListener.
"""

from __future__ import annotations
import sys

import mido
import sounddevice as sd
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QHBoxLayout,
    QLabel, QComboBox, QPushButton, QFrame,
)

_STYLE = """
QDialog {
    background: #0e0e14;
}
QLabel {
    color: #aaaacc;
    font-size: 11px;
}
QLabel#title {
    color: #ffffff;
    font-size: 16px;
    font-weight: bold;
    letter-spacing: 2px;
}
QLabel#subtitle {
    color: #555577;
    font-size: 10px;
    letter-spacing: 1px;
}
QComboBox {
    background: #1a1a26;
    color: #ccccee;
    border: 1px solid #333355;
    border-radius: 4px;
    padding: 5px 8px;
    font-size: 11px;
}
QComboBox::drop-down {
    border: none;
}
QComboBox QAbstractItemView {
    background: #1a1a26;
    color: #ccccee;
    selection-background-color: #2a2a44;
    border: 1px solid #333355;
}
QPushButton {
    background: #2a2a55;
    color: #aaaaff;
    border: 1px solid #4444aa;
    border-radius: 4px;
    padding: 10px 10px 20px;
    font-size: 12px;
    letter-spacing: 1px;
}
QPushButton:hover {
    background: #3a3a77;
    color: #ffffff;
}
QPushButton:pressed {
    background: #1a1a44;
}
QFrame#divider {
    color: #222233;
}
"""


def _output_devices() -> list[str]:
    devices = sd.query_devices()
    return [d["name"] for d in devices if d["max_output_channels"] > 0]


def _midi_inputs() -> list[str]:
    return mido.get_input_names()


class LaunchDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("NeoChucao")
        self.setFixedSize(380, 230)
        self.setStyleSheet(_STYLE)
        self.setWindowFlags(Qt.Dialog | Qt.WindowCloseButtonHint)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 20, 24, 20)
        layout.setSpacing(10)

        # Title
        title = QLabel("NEOCHUCAO")
        title.setObjectName("title")
        sub = QLabel("latent space instrument")
        sub.setObjectName("subtitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # Divider
        line = QFrame()
        line.setObjectName("divider")
        line.setFrameShape(QFrame.HLine)
        line.setFixedHeight(1)
        layout.addSpacing(4)
        layout.addWidget(line)
        layout.addSpacing(4)

        # Output device
        layout.addWidget(QLabel("Audio Output"))
        self._out_combo = QComboBox()
        outputs = _output_devices()
        self._out_combo.addItems(outputs if outputs else ["(no output devices found)"])
        layout.addWidget(self._out_combo)

        # MIDI input
        layout.addWidget(QLabel("MIDI Input"))
        self._midi_combo = QComboBox()
        inputs = ["Computer Keyboard"] + _midi_inputs()
        self._midi_combo.addItems(inputs)
        layout.addWidget(self._midi_combo)

        layout.addSpacing(6)

        # Launch button
        btn_row = QHBoxLayout()
        btn_row.addStretch()
        self._launch_btn = QPushButton("LAUNCH")
        self._launch_btn.setDefault(True)
        self._launch_btn.clicked.connect(self.accept)
        btn_row.addWidget(self._launch_btn)
        layout.addLayout(btn_row)

    @property
    def output_device(self) -> str:
        return self._out_combo.currentText()

    @property
    def midi_device(self) -> str:
        return self._midi_combo.currentText()


def show_launch_dialog() -> tuple[str, str] | None:
    """
    Show the device selection dialog.
    Returns (output_device, midi_device), or None if the user cancels.
    Must be called before vispy starts (creates/reuses the QApplication).
    """
    app = QApplication.instance() or QApplication(sys.argv)
    dlg = LaunchDialog()
    if dlg.exec_() == QDialog.Accepted:
        return dlg.output_device, dlg.midi_device
    return None
