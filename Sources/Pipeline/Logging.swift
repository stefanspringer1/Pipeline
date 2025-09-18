import Foundation

extension Execution {
    
    public func log(_ type: InfoType, _ message: String) {
        executionInfoConsumer.consume(
            ExecutionInfo(
                type: type,
                metadata: metadata,
                level: level,
                structuralID: UUID(),
                event: .message(
                    message: message
                )
            )
        )
    }
    
    public func log(_ type: InfoType, _ message: MultiLanguageText) {
        log(type, message.forLanguage(language))
    }
    
    public func log(_ message: Message, _ arguments: String...) {
        let core = message.fact.forLanguage(language).filling(withArguments: arguments)
        let idPrefix = message.id != nil ? "[\(message.id!)]: " : ""
        let solutionPostfix = message.solution != nil ? " → \(message.solution!.forLanguage(language).filling(withArguments: arguments))" : ""
        log(message.type, "\(idPrefix)\(core)\(solutionPostfix)")
    }
    
}

extension AsyncExecution {
    
    public func log(_ type: InfoType, _ message: String) async {
        synchronousExecution.executionInfoConsumer.consume(
            ExecutionInfo(
                type: type,
                metadata: synchronousExecution.metadata,
                level: synchronousExecution.level,
                structuralID: UUID(),
                event: .message(
                    message: message
                )
            )
        )
    }
    
    public func log(_ type: InfoType, _ message: MultiLanguageText) async {
        await log(type, message.forLanguage(synchronousExecution.language))
    }
    
    public func log(_ message: Message, _ arguments: String...) async {
        let core = message.fact.forLanguage(synchronousExecution.language).filling(withArguments: arguments)
        let idPrefix = message.id != nil ? "[\(message.id!)]: " : ""
        let solutionPostfix = message.solution != nil ? " → \(message.solution!.forLanguage(synchronousExecution.language).filling(withArguments: arguments))" : ""
        await log(message.type, "\(idPrefix)\(core)\(solutionPostfix)")
    }
    
}

public typealias MultiLanguageText = [Language:String]

extension MultiLanguageText {
    public func forLanguage(_ language: Language) -> String {
        self[language] ?? self.first?.value ?? ""
    }
}

/// A message contains a message ID, a message type, and fact and maybe solution as `MultiLanguageText`.
public struct Message {
    
    public let id: String?
    public let type: InfoType
    public let fact: MultiLanguageText
    public let solution: MultiLanguageText?
    
    public init(id: String?, type: InfoType, fact: MultiLanguageText, solution: MultiLanguageText? = nil) {
        self.id = id
        self.type = type
        self.fact = fact
        self.solution = solution
    }
    
    public func setting(type newType: InfoType) -> Message {
        return Message(id: id, type: newType, fact: fact, solution: solution)
    }
    
}

public extension MultiLanguageText {
    
    /// Replaces the placeholders in all message texts of an instance of
    /// `LocalizingMessage` by the accordings arguments.
     func filling(withArguments arguments: [String]?) -> MultiLanguageText {
        guard let arguments = arguments else {
            return self
        }
        var newMessage = [Language:String]()
        self.forEach{ language, text in
            newMessage[language] = text.filling(withArguments: arguments)
        }
        return newMessage
    }
    
    /// Replaces the placeholders in all message texts of an instance of
    /// `LocalizingMessage` by the accordings arguments.
    func filling(withArguments arguments: String...) -> MultiLanguageText {
        filling(withArguments: arguments)
    }
}

public extension String {
    
    /// A message text can have placeholders $1, $2, ... which are
    /// replaced by the additional textual arguments of the `log`
    /// method. This function replaces the placeholders by those
    /// arguments.
    func filling(withArguments arguments: [String]) -> String {
        var i = 0
        var s = self
        arguments.forEach { argument in
            s = s.replacingOccurrences(of: "$\(i)", with: argument)
            i += 1
        }
        return s
    }
    
    /// A message text can have placeholders $1, $2, ... which are
    /// replaced by the additional textual arguments of the `log`
    /// method. This function replaces the placeholders by those
    /// arguments.
    func filling(withArguments arguments: String...) -> String {
        filling(withArguments: arguments)
    }
    
}

// The message type that informs about the severity a message.
//
// It conforms to `Comparable` so there is an order of severity.
public enum InfoType: Comparable, Codable, Sendable, Hashable {
    
    /// Debugging information.
    case debug
    
    /// Information about the progress (e.g. the steps being executed).
    case progress
    
    /// Information from the processing.
    case info
    
    /// Information about the execution for a work item, e.g. starting.
    case iteration
    
    /// Warnings from the processing.
    case warning
    
    /// Errors from the processing.
    case error
    
    /// A fatal error, the execution (for the data item being processed) is
    /// then abandoned.
    case fatal
    
    /// The program or process that has been startet to be in charge for
    /// the whole processing of a work item is lost (crashed or hanging).
    case loss
    
    /// A deadly error, i.e. not only the processing for one work item
    /// has to be abandoned, but the whole processing cannot continue.
    case deadly

}

// Uses ISO language codes.
    public enum Language: String, Hashable {
    case aa
    case ab
    case ace
    case ach
    case ada
    case ady
    case ae
    case aeb
    case af
    case afh
    case agq
    case ain
    case ak
    case akk
    case akz
    case ale
    case aln
    case alt
    case am
    case an
    case ang
    case anp
    case apw
    case ar
    case arc
    case arn
    case aro
    case arp
    case arq
    case ars
    case arw
    case ary
    case arz
    case `as`
    case asa
    case ase
    case ast
    case av
    case avk
    case awa
    case ay
    case az
    case ba
    case bal
    case ban
    case bar
    case bas
    case bax
    case bbc
    case bbj
    case be
    case bej
    case bem
    case ber
    case bew
    case bez
    case bfd
    case bfq
    case bg
    case bgc
    case bgn
    case bho
    case bi
    case bik
    case bin
    case bjn
    case bkm
    case bla
    case blo
    case bm
    case bn
    case bo
    case bpy
    case bqi
    case br
    case bra
    case brh
    case brx
    case bs
    case bss
    case bua
    case bug
    case bum
    case byn
    case byv
    case ca
    case cad
    case car
    case cay
    case cch
    case ccp
    case ce
    case ceb
    case cgg
    case ch
    case chb
    case chg
    case chk
    case chm
    case chn
    case cho
    case chp
    case chr
    case chy
    case cic
    case ckb
    case co
    case cop
    case cps
    case cr
    case crh
    case cs
    case csb
    case csw
    case cu
    case cv
    case cy
    case da
    case dak
    case dar
    case dav
    case de
    case del
    case den
    case dgr
    case din
    case dje
    case doi
    case dsb
    case dtp
    case dua
    case dum
    case dv
    case dyo
    case dyu
    case dz
    case dzg
    case ebu
    case ee
    case efi
    case egl
    case egy
    case eka
    case el
    case elx
    case en
    case enm
    case eo
    case es
    case esu
    case et
    case eu
    case ewo
    case ext
    case fa
    case fan
    case fat
    case ff
    case fi
    case fil
    case fit
    case fj
    case fo
    case fon
    case fr
    case frc
    case frm
    case fro
    case frp
    case frr
    case frs
    case fur
    case fy
    case ga
    case gaa
    case gag
    case gan
    case gay
    case gba
    case gbz
    case gd
    case gez
    case gil
    case gl
    case glk
    case gmh
    case gn
    case goh
    case gom
    case gon
    case gor
    case got
    case grb
    case grc
    case gsw
    case gu
    case guc
    case gur
    case guz
    case gv
    case gwi
    case ha
    case hai
    case hak
    case haw
    case he
    case hi
    case hif
    case hil
    case hit
    case hmn
    case ho
    case hr
    case hsb
    case hsn
    case ht
    case hu
    case hup
    case hy
    case hz
    case ia
    case iba
    case ibb
    case id
    case ie
    case ig
    case ii
    case ik
    case ilo
    case inh
    case io
    case `is`
    case it
    case iu
    case izh
    case ja
    case jam
    case jbo
    case jgo
    case jmc
    case jpr
    case jrb
    case jut
    case jv
    case ka
    case kaa
    case kab
    case kac
    case kaj
    case kam
    case kaw
    case kbd
    case kbl
    case kcg
    case kde
    case kea
    case ken
    case kfo
    case kg
    case kgp
    case kha
    case kho
    case khq
    case khw
    case ki
    case kiu
    case kj
    case kk
    case kkj
    case kl
    case kln
    case km
    case kmb
    case kn
    case ko
    case koi
    case kok
    case kos
    case kpe
    case kr
    case krc
    case kri
    case krj
    case krl
    case kru
    case ks
    case ksb
    case ksf
    case ksh
    case ku
    case kum
    case kut
    case kv
    case kw
    case kxv
    case ky
    case la
    case lad
    case lag
    case lah
    case lam
    case lb
    case lez
    case lfn
    case lg
    case li
    case lij
    case liv
    case lkt
    case lmo
    case ln
    case lo
    case lol
    case loz
    case lrc
    case lt
    case ltg
    case lu
    case lua
    case lui
    case lun
    case luo
    case lus
    case lut
    case luy
    case lv
    case lzh
    case lzz
    case mad
    case maf
    case mag
    case mai
    case mak
    case man
    case mas
    case mde
    case mdf
    case mdh
    case mdr
    case men
    case mer
    case mfe
    case mg
    case mga
    case mgh
    case mgo
    case mh
    case mi
    case mic
    case mid
    case min
    case mis
    case mk
    case ml
    case mn
    case mnc
    case mni
    case moh
    case mos
    case mr
    case mrj
    case ms
    case mt
    case mua
    case mul
    case mus
    case mwl
    case mwr
    case mwv
    case my
    case mye
    case myv
    case mzn
    case na
    case nan
    case nap
    case naq
    case nb
    case nd
    case nds
    case ne
    case new
    case ng
    case nia
    case niu
    case njo
    case nl
    case nmg
    case nn
    case nnh
    case nnp
    case no
    case nog
    case non
    case nov
    case nqo
    case nr
    case nso
    case nus
    case nv
    case nwc
    case ny
    case nym
    case nyn
    case nyo
    case nzi
    case oc
    case oj
    case om
    case or
    case os
    case osa
    case ota
    case otk
    case oui
    case pa
    case pag
    case pal
    case pam
    case pap
    case pau
    case pcd
    case pcm
    case pdc
    case pdt
    case peo
    case pfl
    case phn
    case pi
    case pl
    case pms
    case pnt
    case pon
    case pqm
    case prg
    case pro
    case ps
    case pt
    case qu
    case quc
    case qug
    case raj
    case rap
    case rar
    case rej
    case rgn
    case rhg
    case rif
    case rm
    case rn
    case ro
    case rof
    case rom
    case rtm
    case ru
    case rue
    case rug
    case rup
    case rw
    case rwk
    case sa
    case sad
    case sah
    case sam
    case saq
    case sas
    case sat
    case saz
    case sba
    case sbp
    case sc
    case scn
    case sco
    case sd
    case sdc
    case sdh
    case se
    case see
    case seh
    case sei
    case sel
    case ses
    case sg
    case sga
    case sgs
    case shi
    case shn
    case shu
    case si
    case sid
    case sjd
    case sje
    case sju
    case sk
    case sl
    case sli
    case sly
    case sm
    case sma
    case smj
    case smn
    case sms
    case sn
    case snk
    case so
    case sog
    case sq
    case sr
    case srn
    case srr
    case ss
    case ssy
    case st
    case stq
    case su
    case suk
    case sus
    case sux
    case sv
    case sw
    case swb
    case syc
    case syr
    case szl
    case ta
    case tcy
    case te
    case tem
    case teo
    case ter
    case tet
    case tg
    case th
    case ti
    case tig
    case tiv
    case tk
    case tkl
    case tkr
    case tlh
    case tli
    case tly
    case tmh
    case tn
    case to
    case tog
    case tok
    case tpi
    case tr
    case tru
    case trv
    case ts
    case tsd
    case tsi
    case tt
    case ttt
    case tum
    case tvl
    case tw
    case twq
    case ty
    case tyv
    case tzm
    case udm
    case ug
    case uga
    case uk
    case umb
    case und
    case ur
    case uz
    case vai
    case ve
    case vec
    case vep
    case vi
    case vls
    case vmf
    case vmw
    case vo
    case vot
    case vro
    case vun
    case wa
    case wae
    case wal
    case war
    case was
    case wbp
    case wo
    case wuu
    case xal
    case xh
    case xmf
    case xnr
    case xog
    case yao
    case yap
    case yav
    case ybb
    case yi
    case yo
    case yrl
    case yue
    case za
    case zap
    case zbl
    case zea
    case zen
    case zgh
    case zh
    case zu
    case zun
    case zxx
    case zza
}
