// SPDX-License-Identifier: GPL-3.0-or-later
// Adapter for unmodified Fairy-Stockfish; see native/README.md for pinned sources.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <atomic>
#include <mutex>
#include <algorithm>
#include "bitboard.h"
#include "endgame.h"
#include "evaluate.h"
#include "movegen.h"
#include "position.h"
#include "psqt.h"
#include "search.h"
#include "thread.h"
#include "tt.h"
#include "uci.h"
#include "piece.h"
#include "variant.h"

namespace SF = Stockfish;
using namespace godot;
namespace {
std::atomic_bool reserved{false}, cancelled{false};
std::mutex engine_mutex;
bool initialized = false;

bool valid_start(const std::string &fen) {
    const std::string orders[] = {"nbbn", "bnbn", "nbnb", "bnnb"};
    for (const auto &han : orders) for (const auto &cho : orders) {
        std::string bottom = "r" + cho.substr(0, 2) + "a1a" + cho.substr(2) + "r";
        std::transform(bottom.begin(), bottom.end(), bottom.begin(), ::toupper);
        if (fen == "r" + han.substr(0, 2) + "a1a" + han.substr(2) + "r/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/" + bottom + " w - - 0 1") return true;
    }
    return false;
}
void initialize_engine() {
    if (initialized) return;
    SF::pieceMap.init(); SF::variants.init();
    char name[] = "janggi"; char *argv[] = {name};
    SF::CommandLine::init(1, argv);
    SF::UCI::init(SF::Options);
    SF::Tune::init();
    SF::PSQT::init(SF::variants.find(SF::Options["UCI_Variant"])->second);
    SF::Bitboards::init(); SF::Position::init(); SF::Bitbases::init(); SF::Endgames::init();
    SF::Threads.set(1);
    SF::Options["Use NNUE"] = std::string("false");
    SF::Options["UCI_Variant"] = std::string("janggi");
    SF::Options["Hash"] = std::string("16");
    SF::Search::clear();
    initialized = true;
}
}

class JanggiNative : public RefCounted {
    GDCLASS(JanggiNative, RefCounted)
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("prepare"), &JanggiNative::prepare);
        ClassDB::bind_method(D_METHOD("cancel"), &JanggiNative::cancel);
        ClassDB::bind_method(D_METHOD("analyze", "initial_fen", "moves"), &JanggiNative::analyze);
    }
public:
    bool prepare() {
        bool expected = false;
        if (!reserved.compare_exchange_strong(expected, true)) return false;
        cancelled = false;
        return true;
    }
    void cancel() { cancelled = true; SF::Threads.stop = true; }
    Dictionary analyze(String initial_fen, PackedStringArray moves) {
        std::lock_guard<std::mutex> lock(engine_mutex);
        struct Release { ~Release() { reserved = false; } } release;
        Dictionary result;
        auto error = [&](const char *text) { result["error"] = text; return result; };
        const std::string fen = initial_fen.utf8().get_data();
        if (!valid_start(fen) || moves.size() > 4096) return error("Invalid initial position or move count");
        if (cancelled) return error("Cancelled");
        initialize_engine();
        SF::StateListPtr states(new std::deque<SF::StateInfo>(1));
        SF::Position pos;
        pos.set(SF::variants.find("janggi")->second, fen, false, &states->back(), SF::Threads.main());
        for (int i = 0; i < moves.size(); ++i) {
            SF::Value outcome;
            if (cancelled) return error("Cancelled");
            if (pos.is_game_end(outcome)) return error("Moves after game end");
            std::string move_text = moves[i].utf8().get_data();
            const SF::Move move = SF::UCI::to_move(pos, move_text);
            if (move == SF::MOVE_NONE) return error("Illegal move history");
            states->emplace_back(); pos.do_move(move, states->back());
        }
        SF::Value outcome;
        if (pos.is_game_end(outcome) || SF::MoveList<SF::LEGAL>(pos).size() == 0) return error("Game is over");
        if (cancelled) return error("Cancelled");
        SF::Search::clear();
        SF::Search::LimitsType limits;
        limits.startTime = SF::now(); limits.movetime = 300;
        SF::Threads.start_thinking(pos, states, limits, false);
        if (cancelled) SF::Threads.stop = true;
        SF::Threads.main()->wait_for_search_finished();
        if (cancelled) return error("Cancelled");
        const auto *thread = SF::Threads.main();
        if (thread->rootMoves.empty() || thread->rootMoves[0].pv.empty()) return error("No recommendation");
        const auto best = thread->rootMoves[0].pv[0];
        if (!SF::MoveList<SF::LEGAL>(pos).contains(best)) return error("Illegal engine result");
        result["move"] = String(SF::UCI::move(pos, best).c_str());
        result["fen"] = String(pos.fen().c_str());
        result["depth"] = int(thread->completedDepth);
        result["elapsed_ms"] = int(SF::now() - limits.startTime);
        result["source"] = "android-native-classical";
        return result;
    }
};

void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<JanggiNative>();
}
void shutdown(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    cancelled = true; SF::Threads.stop = true;
    std::lock_guard<std::mutex> lock(engine_mutex);
    if (initialized) SF::Threads.set(0);
}
extern "C" GDExtensionBool GDE_EXPORT janggi_library_init(GDExtensionInterfaceGetProcAddress address, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(address, library, initialization);
    init.register_initializer(initialize); init.register_terminator(shutdown);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
