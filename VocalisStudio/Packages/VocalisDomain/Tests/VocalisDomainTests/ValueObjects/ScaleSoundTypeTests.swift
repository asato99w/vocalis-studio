import XCTest
@testable import VocalisDomain

final class ScaleSoundTypeTests: XCTestCase {

    // MARK: - Test 1: All Cases Count

    func testAllCasesCount() {
        // Given: ScaleSoundType.allCases
        let allCases = ScaleSoundType.allCases

        // Then: 8種類すべて定義されている
        XCTAssertEqual(allCases.count, 8, "Should have 8 sound types")

        // すべてのケースが含まれていることを確認
        XCTAssertTrue(allCases.contains(.acousticGrandPiano))
        XCTAssertTrue(allCases.contains(.electricPiano))
        XCTAssertTrue(allCases.contains(.acousticGuitar))
        XCTAssertTrue(allCases.contains(.vibraphone))
        XCTAssertTrue(allCases.contains(.marimba))
        XCTAssertTrue(allCases.contains(.flute))
        XCTAssertTrue(allCases.contains(.clarinet))
        XCTAssertTrue(allCases.contains(.sineWave))
    }

    // MARK: - Test 2: Default Value

    func testDefaultValue() {
        // Given: ScaleSoundType.default
        let defaultType = ScaleSoundType.default

        // Then: acousticGrandPianoがデフォルト
        XCTAssertEqual(defaultType, .acousticGrandPiano)
    }

    // MARK: - Test 3: MIDI Program Numbers

    func testMIDIProgramNumbers() {
        // General MIDI仕様に準拠しているか確認

        // Acoustic Grand Piano: Program 0
        XCTAssertEqual(ScaleSoundType.acousticGrandPiano.midiProgram, 0)

        // Electric Piano 1: Program 4
        XCTAssertEqual(ScaleSoundType.electricPiano.midiProgram, 4)

        // Acoustic Guitar (nylon): Program 24
        XCTAssertEqual(ScaleSoundType.acousticGuitar.midiProgram, 24)

        // Vibraphone: Program 11
        XCTAssertEqual(ScaleSoundType.vibraphone.midiProgram, 11)

        // Marimba: Program 12
        XCTAssertEqual(ScaleSoundType.marimba.midiProgram, 12)

        // Flute: Program 73
        XCTAssertEqual(ScaleSoundType.flute.midiProgram, 73)

        // Clarinet: Program 71
        XCTAssertEqual(ScaleSoundType.clarinet.midiProgram, 71)
    }

    // MARK: - Test 4: Sine Wave Has No MIDI Program

    func testSineWaveHasNoMIDIProgram() {
        // Given: Sine Wave
        let sineWave = ScaleSoundType.sineWave

        // Then: MIDI Programはnil（プログラム生成）
        XCTAssertNil(sineWave.midiProgram)
    }

    // MARK: - Test 5: Display Names

    func testDisplayNames() {
        // すべての音源に適切な日本語表示名があることを確認

        XCTAssertEqual(
            ScaleSoundType.acousticGrandPiano.displayName,
            "アコースティック・グランド・ピアノ"
        )
        XCTAssertEqual(
            ScaleSoundType.electricPiano.displayName,
            "エレクトリック・ピアノ"
        )
        XCTAssertEqual(
            ScaleSoundType.acousticGuitar.displayName,
            "アコースティック・ギター"
        )
        XCTAssertEqual(
            ScaleSoundType.vibraphone.displayName,
            "ヴィブラフォン"
        )
        XCTAssertEqual(
            ScaleSoundType.marimba.displayName,
            "マリンバ"
        )
        XCTAssertEqual(
            ScaleSoundType.flute.displayName,
            "フルート"
        )
        XCTAssertEqual(
            ScaleSoundType.clarinet.displayName,
            "クラリネット"
        )
        XCTAssertEqual(
            ScaleSoundType.sineWave.displayName,
            "サイン波"
        )

        // すべての表示名が空でないことを確認
        for soundType in ScaleSoundType.allCases {
            XCTAssertFalse(
                soundType.displayName.isEmpty,
                "\(soundType) should have non-empty display name"
            )
        }
    }

    // MARK: - Test 6: Icons

    func testIcons() {
        // すべての音源にアイコンが定義されていることを確認

        XCTAssertEqual(ScaleSoundType.acousticGrandPiano.icon, "🎹")
        XCTAssertEqual(ScaleSoundType.electricPiano.icon, "🎹✨")
        XCTAssertEqual(ScaleSoundType.acousticGuitar.icon, "🎸")
        XCTAssertEqual(ScaleSoundType.vibraphone.icon, "🎵")
        XCTAssertEqual(ScaleSoundType.marimba.icon, "🥁")
        XCTAssertEqual(ScaleSoundType.flute.icon, "🎺")
        XCTAssertEqual(ScaleSoundType.clarinet.icon, "🎷")
        XCTAssertEqual(ScaleSoundType.sineWave.icon, "〜")

        // すべてのアイコンが空でないことを確認
        for soundType in ScaleSoundType.allCases {
            XCTAssertFalse(
                soundType.icon.isEmpty,
                "\(soundType) should have non-empty icon"
            )
        }

        // アイコンがユニークであることを確認
        let icons = ScaleSoundType.allCases.map { $0.icon }
        let uniqueIcons = Set(icons)
        XCTAssertEqual(
            icons.count,
            uniqueIcons.count,
            "All icons should be unique"
        )
    }

    // MARK: - Test 7: Descriptions

    func testDescriptions() {
        // すべての音源に説明文が定義されていることを確認

        for soundType in ScaleSoundType.allCases {
            XCTAssertFalse(
                soundType.description.isEmpty,
                "\(soundType) should have non-empty description"
            )

            // 説明文が一定の長さ以上あることを確認（品質チェック）
            XCTAssertGreaterThan(
                soundType.description.count,
                10,
                "\(soundType) description should be descriptive"
            )
        }
    }

    // MARK: - Test 8: Codable Conformance

    func testCodableConformance() throws {
        // すべての音源タイプをエンコード/デコードできることを確認

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for soundType in ScaleSoundType.allCases {
            // When: エンコード
            let data = try encoder.encode(soundType)

            // Then: デコード成功
            let decoded = try decoder.decode(ScaleSoundType.self, from: data)

            // Then: 同じ値が復元される
            XCTAssertEqual(decoded, soundType)
        }
    }

    // MARK: - Test 9: Hashable Conformance

    func testHashableConformance() {
        // すべての音源タイプがハッシュ可能であることを確認

        var hashValues: Set<Int> = []

        for soundType in ScaleSoundType.allCases {
            let hashValue = soundType.hashValue
            hashValues.insert(hashValue)
        }

        // すべてのハッシュ値がユニークであることを確認
        XCTAssertEqual(
            hashValues.count,
            ScaleSoundType.allCases.count,
            "All hash values should be unique"
        )
    }

    // MARK: - Test 10: CaseIterable Conformance

    func testCaseIterableConformance() {
        // allCasesの順序が期待通りであることを確認

        let expectedOrder: [ScaleSoundType] = [
            .acousticGrandPiano,
            .electricPiano,
            .acousticGuitar,
            .vibraphone,
            .marimba,
            .flute,
            .clarinet,
            .sineWave
        ]

        XCTAssertEqual(ScaleSoundType.allCases, expectedOrder)
    }
}
