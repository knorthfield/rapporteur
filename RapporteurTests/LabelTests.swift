import Testing
@testable import Rapporteur

struct LabelTests {
    @Test func readsTheHexColour() {
        let rgb = Label(name: "bug", color: "ff8000").rgb
        #expect(rgb.red == 1)
        #expect(abs(rgb.green - 128.0 / 255) < 0.001)
        #expect(rgb.blue == 0)
    }

    @Test func usesGreyForATextThatIsNotAColour() {
        #expect(Label(name: "bug", color: "nope").rgb == (0.5, 0.5, 0.5))
    }

    @Test func usesDarkTextOnLightColours() {
        #expect(Label(name: "question", color: "fef2c0").needsDarkText)
        #expect(!Label(name: "bug", color: "5319e7").needsDarkText)
    }
}
