import QtQuick
import "../../../services"
import "resonance"

MediaWidget {
  id: root
  BarApi { id: barApi }
  bar: barApi
}
