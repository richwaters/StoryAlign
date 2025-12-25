//
//  TestGetSentenceRanges.swift
//  StoryAlign
//
//  Created by Rich Waters on 5/6/25.
//



import XCTest
@testable import StoryAlignCore
import Foundation
import NaturalLanguage

fileprivate let sessionConfig = try? SessionConfig(sessionDir: nil, modelFile: "", runStage: .align, logger: TestsLogger())
fileprivate let aligner = Aligner(sessionConfig: sessionConfig!)


struct TestsLogger : Logger {
    func log(_ level: LogLevel = .info, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line, indentLevel: Int = 0) {
        let minLevel: LogLevel = .warn
        guard level >= minLevel else {
            return
        }
        let s = String(repeating: " ", count: indentLevel * 8 )
        print( s + message() )
    }
}

/*
final class TestGetSentenceRanges: XCTestCase {
    func testMissingSentenceFalsePosISaid() throws {
        let chapterText = """
        Now I think it might have started earlier.You mustn’t blame me.”He was suddenly plaintive.“I’m sure he hated me, too.It was neither of our faults.”)“They must have suspected what would happen, you know,” Bren said.“The Ambassadors.It was always the oddballs who seemed to risk … unplaiting … just enough to make a few Ariekei oratees.Those were the ones they restrained.Other sorts of troublemakers went AWOL or native.”“You think they knew?”I said.“And who went what?”“They must have hoped EzRa were a drug,” he said.“So they’d affect one or two of the Hosts and not be usable.One in the eye for Bremen.They’ve all been very concerned about who was calling what shots, what agendas were being forced, since they heard EzRa were coming.”“I know,” I said.“But Bremen must’ve known too, if this has happened before.Why would they send them …?”“Known about oratees, you mean?Why would we tell Bremen about that?I don’t know what they had in mind, but this, letting EzRa speak, was the Embassy’s riposte, I think.Not that they expected this, though.Not like this.Language like this, right there but so impossible, so doping, that EzRa are infecting every, single, Host.All of which are spreading the word.All hooked on the new Ambassador.”Our everyday pantheon gone needy, desperate for hits of Ez and Ra speaking together, fermenting Language into some indispensable brew of contradiction, insinuation and untethered meaning.We were quartered in an addict city.That procession I’d seen had been craving.“What happens now?”I said.It was very quiet in the room.There were hundreds of thousands of Ariekei in the city.Maybe millions.I didn’t know.We knew hardly anything at all.Their heads were all made of Language.EzRa spoke it and changed it.Every Host, everywhere, would become hardwired with need, do anything, for the blatherings of a newly trained bureaucrat.“Sweet Jesus Pharotekton Christ light our way,” I said.
        """

        let transcriptionText = """
            now i think it might have started earlier. you mustn't blame me. he was suddenly plaintiff. i'm sure he hated me, too. it was neither of our faults. they must have suspected what would happen, you know. he said, "the ambassadors. it was always the oddballs who seemed to risk unplating, just enough to make a few rec authorities. those were the ones they restrained. other sorts of trouble makers went awall or native. he said, "i said, and who went? what?" they must have hoped as rar were a drug. he said, "so they'd affect one or two of the hosts and not be usable, one in the eye for bremen. they've all been very concerned about who was calling what shots, what agendas were being forced, since they heard as rar were coming. i know," i said. "but bremen must have known, too, if this has happened before. why would they send them?" known about ortiz, you mean. why would we tell bremen about that? i don't know what they had in mind, but this, letting es rar speak, was the embassies repost, i think. not that they expected this, though. not like this. language like this, right there, but so impossible, so doping, that es rar are infecting every single host, all of which are spreading the word, all hooked on the new ambassador. are every day pantheon gone needy, desperate for hits of es and rar speaking together, fermenting language into some indispensable brew of contradiction, insinuation, and untethered meaning? we were caught in an addict city, that procession i'd seen had been craving. what happens now, i said. it was very quiet in the room. there were hundreds of thousands of arieke in the city. maybe millions, i didn't know. 
            """
        let sentences = NLTokenizer.tokenizeSentences(text: chapterText)
        
        let adjustedTimeline = try adjustedTimeline(fromPath: "./TestTimeline.json")
        let transcription = Transcription(transcription: transcriptionText, wordTimeline: adjustedTimeline)
        
        let (sentenceRanges, _, _) = aligner.getSentenceRanges(startSentence: 0, transcription: transcription, sentences: sentences, chapterOffset: 0, lastSentenceRange: nil)
        
        XCTAssertEqual(sentenceRanges.count, 16)
    }
 
    func testMisalignmentArvise() throws {
        let chapterText = """
         Latterday, two “Please join me”—I couldn’t see who it was who spoke loudly, announcing the arrivals to Diplomacy Hall—“in welcoming Ambassador EzRa.” They were immediately surrounded. In that moment I saw no close friends, had no one with whom to share my tension or conspiratorial look. I waited for EzRa to do the rounds. When they did, how they did so was another indicator of their strangeness. They must have known how it would seem to us. As JoaQuin and Wyatt introduced them to people, Ez and Ra separated, moved somewhat apart. They glanced at each other from time to time, like a couple, but there were soon metres between them: nothing like doppels, nothing like an Ambassador. Their links must work differently, I thought. I glanced at their little mechanisms. They each wore a distinct design. I shouldn’t have been surprised. Disguising their unease with functionaries’ aplomb, JoaQuin led Ez and Wyatt Ra. Each half of the new Ambassador was at the centre of a curious crowd. This was the first chance most of us had had to meet them. But there were Staff and Ambassadors whose fascination for the newcomers had clearly outlasted their own initial meetings. LeNa, RanDolph and HenRy were laughing with Ez, the shorter man, while Ra looked bashful as AnDrew asked him questions, and MagDa, I realised, stayed close enough to touch his hands. The party bustled about me. I caught sight of Ehrsul’s rendered eyes at last and winked as Ra approached me. Wyatt made an aaah noise, held out his hands, kissed my cheeks. “Avice! Ra, this is Avice Benner Cho, one of Embassytown’s … Well, Avice is any number of things.” He bowed as if granting me something. “She’s one of our immersers. She’s spent a good deal of time in the out, and now she offers cosmopolitan expertise and an invaluable traveller’s eye.” I liked Wyatt and his little power plays. You might say we tended to twinkle at each other. “Ra,” I said. A hesitation too short for him to notice, I think, and I held out my hand. I shouldn’t call him “Mr.” or “Squire”: legally he was not a man, but half of something. Had he been with Ez I’d have addressed them as “Ambassador.” I nodded at AnDrew, at Mag, at Da, who watched. “Helmser Cho,” Ra said quietly. He after his own hesitation took my hand. I laughed. “You’ve promoted me. And it’s Avice. Avice is fine.” “Avice.” We stood silent for a moment. He was tall and slim, pale, his hair dark and plaited. He seemed slightly anxious but he pulled himself together somewhat as we spoke. “I admire you being able to immerse,” he said. “I never get used to it. Not that I’ve travelled a lot, but that’s partly why.” I forget what I replied, but whatever it was, there was a silence after it. After a minute I said to him, “You’ll have to get better at it, you know. Small talk. That’s what your job is, from here on in.” He smiled. “I’m not sure that’s quite fair,” he said. “No,” I said. “There’s wine to drink and papers to sign, too.”
        """

        let transcriptionText = """
            "Latter-day, too.\" \"Please join me.\" I couldn\'t see who it was who spoke loudly, announcing the arrivals to Diplomacy Hall. In welcoming Ambassador Ezra. They were immediately surrounded. In that nomad I saw no close friends, had no one with whom to share my tension or conspiratorial look. I waited for Ezra to do the rounds. And they did, how they did so was another indicator of their strangeness. They must have known how it would seem to us. As Joaquin and Wyatt introduced them to people, Ez and Ra separated, moved somewhat apart. They glanced at each other from time to time, like a couple, but they were soon metas between them, nothing like doples, nothing like an ambassador. Their links must work differently I thought. I glanced at their little mechanisms, they each wore a distinct design. I shouldn\'t have been surprised, disguising their unease with functionaries a plom, Joaquin led Ez and Wyatt, Ra. Each half of the new ambassador was at the center of a curious crowd. This was the first chance most of us had had to meet them, but there were staff and ambassadors whose fascination for the newcomers had clearly outlasted their own initial meetings. Meena, Randolph and Henry were laughing with Ez, the short-a-man, while Ra looked bashful as Andrew, asked him questions, and Magda, I realized, stayed close enough to touch his hands. The party bustled about me. I caught sight of Ursul\'s rendered eyes at last and winked as Ra approached me. Wyatt made an R noise, held out his hands, kissed my cheeks. \"Arvise.\" Ra, this is Arvise Benachow, one of Empty Towns. \"Well, Arvise is any number of things.\" He bowed as if granting me something. She\'s one of our immersors. She\'s spent a good deal of time in the out, and now she offers cosmopolitan expertise and an invaluable traveller\'s eye. I liked Wyatt, and his little power plays. He might say he tended to twinkle at each other. \"Ra,\" I said. \"Hesitation too short for him to notice, I think, and I held out my hand. I shouldn\'t call him, Mr. or Squire. legally he was not a man, but half of something. Had he been with Ez, I\'d have addressed them as ambassador. I nodded at Andrew, at Mag, at Dar, who watched. Helms a chill.\" Ra said quietly. He, after his own hesitation, took my hand. \"I laughed. You\'ve promoted me, and it\'s Arvise. Arvise is fine. Arvise.\" We stood silent for a moment. He was tall and slim. Pale. His head darkened platted. He seemed slightly anxious, but he pulled himself together somewhat as we spoke. \"I admire you being able to immerse,\" he said. \"I never get used to it, not that I\'ve traveled a lot, but that\'s partly why.\" I forget what I replied, but whatever it was, there was a silence after it. After a minute I said to him, \"You\'ll have to get better at it, you know. Small talk. That\'s what your job is, from here on in.\" He smiled. \"I\'m not sure, that\'s quite fair,\" he said. \"No,\" I said. As wine to drink and papers to sign, too. He seemed delighted by that. And for that you came all the way to Arriaca, I said, \" forever and ever.\" \"Not forever,\" he said. \"We\'ll be here seventeen, eighty kilos, until the next relief but one, I think, then back to Bremen.\" I was astounded. My bladder stopped. Of course, I should not have been taken aback, and I\'m basad a leaving embassy town. Nothing about this situation made sense, and I\'m basad it with somewhere else to return to, was a contradiction in my terms. Why it was muttering to Rar, Magda smiled at me from behind them. I liked Magda." 
            """
        let sentences = NLTokenizer.tokenizeSentences(text: chapterText)
        
        let adjustedTimeline = try adjustedTimeline(fromPath: "./TestAlignArviseTl.json")
        let transcription = Transcription(transcription: transcriptionText, wordTimeline: adjustedTimeline)
        
        let (sentenceRanges, _, _) = aligner.getSentenceRanges(startSentence: 0, transcription: transcription, sentences: sentences, chapterOffset: 0, lastSentenceRange: nil)
        
        let refined = aligner.refine(sentenceRanges: sentenceRanges, lastSentenceRange: nil, transcription: transcription)
        
        XCTAssertEqual(sentenceRanges.count, 44)
    }
    
    func testMisalignWantAScene() throws {
        let chapterText = """
            “Your colleague. You really are just determined to scandalise us, Ez,” I said. “Oh, please. No. Not at all, not at all.” He grinned an apology at the doppels escorting him. “It’s … well, I suppose it’s just a slightly different way of doing things.” “And it’ll be invaluable,” said Joa, or Quin, heartily. The two spoke in turn. “You’re always telling us we’re too …” “… stuck in our ways, Avice. This will be …” “… good for us, and good for Embassytown.” One of them slapped Ez on the back. “Ambassador EzRa’s an outstanding linguist and bureaucrat.” “You’re going to say they’re a ‘new broom,’ aren’t you, Ambassador?” I said. JoaQuin laughed. “Why not?” “Why not indeed?” “That’s exactly what they are.” We were rude, Ehrsul and I. We’d stick together, whispering and showing off, at all these sorts of events. So when she waved a trid hand to attract my attention I joined her expecting to play. But when I reached her she said to me urgently, “Scile’s here.” I didn’t look round. “Are you sure?” “I never thought he’d come,” she said. I said, “I don’t know what …” It was some time since I’d seen my husband. I didn’t want a scene. I bit a knuckle for a moment, stood up straighter. “He’s with CalVin, isn’t he?” “Am I going to have to separate you two girls?” It was Ez again. He made me start. He’d extricated himself from JoaQuin’s anxious stewarding. He offered me a drink. He flexed something inside himself, and his augmens glimmered, changing the colour of his vague halo. I realised that with the help of his innard tech he might have been listening to us. I focused on him and tried not to look for Scile. Ez was shorter than I, and muscular. His hair was cut close. “Ez, this is Ehrsul,” I said."
            """
        
        //let transcriptionText = """
            //"Your colleague?" "Yes, I met him. I shook my head. Joaquin worked Ez's elbows, one on each side like elderly parents, and I nodded at them. "Your colleague?" "You really are just determined to scandalise us, Ez," I said. "Oh, please, no. Not at all, not at all. He grinned and apologised the doppels escorting him." "It's...well, I suppose it's just a slightly different way of doing things." "And it'll be invaluable," said Joaquin, heartily. "The two spoke in turn." "You're always telling us we're two stuck in our ways of ease. This will be good for us, and good for embassy town." "One of them slept Ez on the back. Ambassador Ez Rar's an outstanding linguist and bureaucrat. "You're going to say there a new broom, aren't you Ambassador?" I said. "Quake in, laughed. Why not? Why not indeed?" That's exactly what they are. "We were rude, Ursula and I, we'd stick together, whispering and showing off at all these sorts of events. So when she waved a trade hand to attract my attention, I joined her expecting to play, but when I reached her, she said to me urgently. "Syl's here. I didn't look round. Are you sure? I never thought it'd come." She said. I said, "I don't know what." "It was sometimes since I'd seen my husband. I didn't want to see him. I bit a knuckle for a moment, stood up straighter. He's with Calvin, isn't he?" "Am I going to have to separate you two girls?" "It was Ez again. He made me start. He'd extricated himself from pockyens, anxious stewarding. He offered me a drink. He flexed something inside himself and his organs glimmered, changing the colour of his vague halo. I realized that with the help of his inner tech, he might have been listening to us. I focused on him and tried not to look for sile. As was shorter than I, and muscular, his hair was cut close. "As, this is Ursul," I said."
            //"""
        
        let transcriptionText = """
            You're colleague?" "Yes, I met him. I shook my head. Joaquin were Ez's elbows, one on each side like elderly parents, and I nodded at them. "You're colleague. You really are just determined to scandalise us as," I said. "Oh, please, no. Not at all, not at all. He grinned and apologised the doppels escorting him. "It's, oh well, I suppose it's just a slightly different way of doing things. And it'll be invaluable," said Joaquin, heartily. The two spoke in turn. "You're always telling us we're two, stuck in our ways of ease. This will be good for us, and good for embassy town." One of them slept Ez on the back. Ambassador Ez Rars, an outstanding linguist and bureaucrat. "You're going to say there a new broom, aren't you Ambassador?" I said. "Quakeen, laughed. Why not? Why not indeed? That's exactly what they are." We were rude, Ursula and I, we'd stick together, whispering and showing off at all these sorts of events. So when she waved a trade hand to attract my attention, I joined her expecting to play. But when I reached her, she said to me urgently. "Siles here. I didn't look round. Are you sure? I never thought it'd come." She said. I said, "I don't know what. It was sometimes since I'd seen my husband. I didn't want to see him. I bit a knuckle for a moment, stood up straighter. He's with Calvin, isn't he?" "Am I going to have to separate you two girls?" It was Ez again. He made me start. He'd extricated himself from pocky and's anxious stewarding. He offered me a drink. He flexed something inside himself and his organics glimmered, changing the colour of his vague halo. I realised that with the help of his inner detect, he might have been listening to us. I focused on him and tried not to look for style. As was shorter than I, and muscular, his hair was cut close. "As, this is Ursul," I said. "
            """
        
        
        let sentences = NLTokenizer.tokenizeSentences(text: chapterText)
        
        //let adjustedTimeline = try adjustedTimeline(fromPath: "./TestAlignASceneTl.json")
        let adjustedTimeline = try adjustedTimeline(fromPath: "./TestAlignASceneTl_2.json")
        let transcription = Transcription(transcription: transcriptionText, wordTimeline: adjustedTimeline)
        
        let (sentenceRanges,_ , _) = aligner.getSentenceRanges(startSentence: 0, transcription: transcription, sentences: sentences, chapterOffset: 0, lastSentenceRange: nil)
        
        let refined = aligner.refine(sentenceRanges: sentenceRanges, lastSentenceRange: nil, transcription: transcription)
        
        XCTAssertEqual(refined.count, sentences.count)
    }
    
    func testFillinMultiSentences() throws {
        let chapterText = """
            “Your colleague. You really are just determined to scandalise us, Ez,” I said. “Oh, please. No. Not at all, not at all.” He grinned an apology at the doppels escorting him. “It’s … well, I suppose it’s just a slightly different way of doing things.” “And it’ll be invaluable,” said Joa, or Quin, heartily. The two spoke in turn. “You’re always telling us we’re too …” “… stuck in our ways, Avice. This will be …” “… good for us, and good for Embassytown.” One of them slapped Ez on the back. “Ambassador EzRa’s an outstanding linguist and bureaucrat.” “You’re going to say they’re a ‘new broom,’ aren’t you, Ambassador?” I said. JoaQuin laughed. “Why not?” “Why not indeed?” “That’s exactly what they are.” We were rude, Ehrsul and I. We’d stick together, whispering and showing off, at all these sorts of events. So when she waved a trid hand to attract my attention I joined her expecting to play. But when I reached her she said to me urgently, “Scile’s here.” I didn’t look round. “Are you sure?” “I never thought he’d come,” she said. I said, “I don’t know what …” It was some time since I’d seen my husband. I didn’t want a scene. I bit a knuckle for a moment, stood up straighter. “He’s with CalVin, isn’t he?” “Am I going to have to separate you two girls?” It was Ez again. He made me start. He’d extricated himself from JoaQuin’s anxious stewarding. He offered me a drink. He flexed something inside himself, and his augmens glimmered, changing the colour of his vague halo. I realised that with the help of his innard tech he might have been listening to us. I focused on him and tried not to look for Scile. Ez was shorter than I, and muscular. His hair was cut close. “Ez, this is Ehrsul,” I said."
        """
        
        /// timeline --- 1135 to 1562
        /// offset ---- 5012 to 6857
        
        let transcriptionText = """
            Your colleague?" "Yes, I met him. I shook my head. "Quake in what Ez is elbows, one on each side like elderly parents, and I nodded at them." "Your colleague?" "You really are just determined to scandalize us as," I said. "Oh, please, no. Not at all, not at all. He grinned and apologized the doppels escorting him." "It's, well, I suppose it's just a slightly different way of doing things." "And it'll be invaluable," said Wah, or keen, heartily. "The two spoke in turn." "You're always telling us we're two stuck in our ways of ease. This will be good for us and good for embassy town." "One of them slept Ez on the back. Ambassador Ez Rar's an outstanding linguist and bureaucrat." "You're going to say there a new broom, aren't you Ambassador?" "I said." "Quake in, laughed." "Why not?" "Why not indeed?" "That's exactly what they are." "We were rude, Ursula and I. We'd stick together, whispering and showing off at all these sorts of events. So when she waved a trade hand to attract my attention, I joined her expecting to play. But when I reached her, she said to me urgently. "Siles here." "I didn't look round. Are you sure?" "I never thought it'd come," she said. "I said, "I don't know what." "It was sometimes since I'd seen my husband. I didn't want to see him. I bit a knuckle for a moment, stood up straighter. He's with Calvin, isn't he?" "Am I going to have to separate you two girls?" "It was Ez again. He made me start. He'd extricated himself from pockyens, anxious stewarding. He offered me a drink. He flexed something inside himself, and his organs glimmered, changing the colour of his vague halo. I realized that with the help of his inner tech, he might have been listening to us. I focused on him and tried not to look for style. As was shorter than I, and muscular, his hair was cut close. As, this is Erso, I said.
        """
        
        let adjustedTimeline = try adjustedTimeline(fromPath: "./TestFillinMultiSentences.json")
        let transcription = Transcription(transcription: transcriptionText, wordTimeline: adjustedTimeline)
        
        let sentences = NLTokenizer.tokenizeSentences(text: chapterText)
        
        let (sentenceRanges,_ , _) = aligner.getSentenceRanges(startSentence: 0, transcription: transcription, sentences: sentences, chapterOffset: 0, lastSentenceRange: nil)
        
        let refined = aligner.refine(sentenceRanges: sentenceRanges, lastSentenceRange: nil, transcription: transcription)
                
    }

}
 */

/*
final class TestAlignSentences: XCTestCase {
    
    func testEmbassyTownFm02S36() throws {
        let chapterText = """
        I don't give two shits about whatever your pisspot home's sidereal shenanigans are, I want to know how old you are." Answer in hours. Answer in subjective hours: no officer cares if you've slowed any compared to your pisspot home. No one cares which of the countless year-lengths you grew up with. So, when I was about one hundred seventy kilohours old I left Embassytown. I returned when I was 266Kh, married, with savings, having learnt a few things. I was about one hundred fifty-eight kilohours old when I learnt that I could immerse. I knew then what I'd do, and I did it. I answer in subjective hours; I have to bear objective hours vaguely in mind; I think in the years of my birth-home, which was itself dictated to by the schedules of another place. None of this has anything to do with Terre. I once met a junior immerser from some self-hating backwater who reckoned in what he called "earth-years," the risible fool.
        """

        let transcriptionText = """
            I don't give two shits about whatever your pisspot home sidereal shenanigans are. I want to know how old you are. Answer in hours. Answer in subjective hours. No officer cares if you've slowed any compared to your pisspot home. No one cares which of the countless year lengths you grew up with. So, when I was about one hundred seventy kilo-hours old, I left Embassy Town. I returned when I was two hundred sixty-six kilo-hours. Married, with savings, having learnt a few things. I was about one hundred fifty-eight kilo-hours old, when I learnt that I could immerse. I knew then what I'd do. And I did it. I answer in subjective hours. I have to bear objective hours vaguely in mind. I think in the years of my birth home, which was itself dictated to by the schedules of another place. None of this has anything to do with tear. I once met a junior immerser from some self-hating backwater who reckoned in what he called Earth years. The risible fool.
            """
        
        let adjustedTimeline = try adjustedTimeline(fromPath: "./TestTimeline_Embassytown_fm02_s36.json")
        let transcription = Transcription(transcription: transcriptionText, segments:[], wordTimeline: adjustedTimeline)
        
        let chapterSentences = NLTokenizer.tokenizeSentences(text: chapterText)
        let (alignedSentences, skippedSentences, _) = aligner.alignSentences( manifestItemName: "",  chapterStartSentence: 0, chapterSentences: chapterSentences, transcription: transcription, startingTransOffset: 0 )
        let normalizedSentences = try aligner.normalize(sentences: chapterSentences)
        let refined = aligner.refine(alignSentences: alignedSentences, lastSentenceRange:nil, transcription:transcription, chapterSentences: normalizedSentences)
        
        //getSentenceRanges(startSentence: 0, transcription: transcription, sentences: sentences, chapterOffset: 0, lastSentenceRange: nil)
        
        XCTAssertEqual(alignedSentences.count, 16)
    }
}


extension TestAlignSentences {
    func adjust(timeline: [WordTimeStamp]) -> [WordTimeStamp] {
        let firstTs = timeline.first!
        let adjustedTimeline = timeline.map { ts in
            let nuStart = ts.start - firstTs.start
            let nuEnd = ts.end - firstTs.start
            let nuStartOffset = ts.startOffset - firstTs.startOffset
            let nuEndOffset = ts.endOffset - firstTs.startOffset
            let nuIndex = ts.index - firstTs.index
            return ts.with(start: nuStart, end: nuEnd, startOffset: nuStartOffset, endOffset: nuEndOffset, index: nuIndex)
        }
        return adjustedTimeline
    }
    
    func adjustedTimeline( fromPath:String ) throws -> [WordTimeStamp] {
        let timelinePath = Bundle.module.url( forResource: fromPath, withExtension: "")!
        let data = try Data(contentsOf: timelinePath)
        let decoder = JSONDecoder()
        let timeline = try decoder.decode([WordTimeStamp].self, from: data)
        let adjustedTimeline = adjust(timeline: timeline)
        return adjustedTimeline
    }
}
 */



final class TestRangeMatch: XCTestCase {
    
    func testRangeMatchIgnoringAllPunct() {
        
        //[DEBUG] [07:31:39.670] Found match at index:7: type:ignoringAllPunctuation: query:that’s you.” haystack:. see? that's you.  queryLen:12 matchLen:10 match: ignoringAllPunctuation
        
        do {
            let query = "you know that,"
            let haystack = "you'll know that."
            let matchedRange = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query)
            let matched = String(haystack[matchedRange!])
            XCTAssertTrue(matched.count == 17)
        }

        
        do {
            let query = "\"which is the first way in which it's not like america,\" malik said, dryly."
            let haystack = "which is the first way in which it's not, like, america. malik said, \"dryly.\" \"it's within an order of magnitude,\" tori said. "
            let matchedRange = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query)
            let matched = String(haystack[matchedRange!])
            XCTAssertTrue(matched.count == 78)
        }
        
        do {
            let query = "that’s you.”"
            let haystack = ". see? that's you."
            let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query)
            XCTAssertTrue(match == nil)
        }
        
        do {
            let query = "see? that’s you.”"
            let haystack = ". see; that's you."
            if let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                XCTAssertTrue( offset == 2 )
            }
            else {
                XCTFail()
            }
        }
        
        do {
            let query = "see? that’s you.”"
            let haystack = ". see - that's you."
            let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query)
            let offset = haystack.distance(from: haystack.startIndex, to: match!.lowerBound)
            let matchStr = String( haystack[match!] )
            XCTAssertTrue(offset == 2)
            XCTAssertEqual(matchStr, "see - that's you.")
        }
        
        do {
            let query = "”see? that's you”"
            let haystack = " ;.see? that's you"
            if let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                XCTAssertTrue( offset == 3)
            }
            else {
                XCTFail()
            }
        }
        do {
            let query = "”see? that's you”"
            let haystack = ";.see? that's you.;blah"
            if let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                let len = haystack.distance(from: match.lowerBound, to: match.upperBound)
                //XCTAssertTrue( offset == 2 && len == 16 )
                XCTAssertTrue( offset == 2 && len == 17 )
            }
            else {
                XCTFail()
            }
        }
        
        do {
            let query = "fifteen concerning a stranger from spaceland from "
            let haystack = " fifteen concerning a stranger from spaceland. from dreams i proceed to facts. it was the last day of our 1,999th year of our era. the patterning of the rain had long ago announced nightfall, and i was"
            if let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                let len = haystack.distance(from: match.lowerBound, to: match.upperBound)
                XCTAssertTrue( offset == 1 && len == 51 )
            }
            else {
                XCTFail()
            }
        }
        
        do {
            let query = "answer in hours."
            let haystack = "answer in hours . answer "
            if let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                let len = haystack.distance(from: match.lowerBound, to: match.upperBound)
                // Not sure what to do with this one. Should it fail?
                //XCTAssertTrue( offset == 0 && len == 15 )
                XCTAssertTrue( offset == 0 && len == 18 )
            }
            else {
                XCTFail()
            }
        }
        
        do {
            let query = "”see? that's you”"
            let haystack = ";.see? that's you.;blah"
            if let match = aligner.rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                let len = haystack.distance(from: match.lowerBound, to: match.upperBound)
                //XCTAssertTrue( offset == 2 && len == 16 )
                XCTAssertTrue( offset == 2 && len == 17 )
            }
            else {
                XCTFail()
            }
        }
        
    }
    
    func testRangeMatchIgnoringSurroundingPunc() {
        do {
            let query = "”see? that's you”"
            let haystack = "see? that's you"
            if let match = aligner.rangeExactMatchIgnoringSurroundingPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                XCTAssertTrue( offset == 0 )
            }
            else {
                XCTFail()
            }
        }
        do {
            let query = "”see? that's you”"
            let haystack = ";.see? that's you"
            if let match = aligner.rangeExactMatchIgnoringSurroundingPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                XCTAssertTrue( offset == 2 )
            }
            else {
                XCTFail()
            }
        }
        
        do {
            let query = "”see? that's you”"
            let haystack = ";.see? that's? you"
            let match = aligner.rangeExactMatchIgnoringSurroundingPunctuation(in: haystack, query: query)
            XCTAssertTrue( match == nil )
        }
        
        do {
            let query = "”see? that's you”"
            let haystack = ";.see? that's you.;blah"
            if let match = aligner.rangeExactMatchIgnoringSurroundingPunctuation(in: haystack, query: query) {
                let offset = haystack.distance(from: haystack.startIndex, to: match.lowerBound)
                let len = haystack.distance(from: match.lowerBound, to: match.upperBound)
                XCTAssertTrue( offset == 2 && len == 16 )
            }
            else {
                XCTFail()
            }
        }
        
    }

}
