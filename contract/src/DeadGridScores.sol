// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DeadGridScores — daily (24h) on-chain leaderboard for DEAD GRID.
/// @notice One leaderboard per UTC day. Each wallet keeps its best score of
///  the day; only the top 10 make the board. Submitting is FREE (gas only).
///  Scores are self-reported by the game client (same trust model as
///  other arcade score contracts): the board is a public record, not
///  a proof of play.
contract DeadGridScores {
    uint256 public constant DAY = 1 days;
    uint256 public constant BOARD_SIZE = 10;
    uint256 public constant MAX_NAME = 16;

    address public owner;

    struct Entry {
        address player;
        string name;
        uint256 score;
        uint256 bnbMicro; // BNB collected, in micro-BNB (1 = 0.000001 BNB)
    }

    mapping(uint256 => Entry[10]) private _top;
    mapping(uint256 => uint256) public topCount;
    mapping(uint256 => mapping(address => uint256)) public bestScore;

    event ScoreSubmitted(uint256 indexed day, address indexed player, string name, uint256 score, uint256 bnbMicro);

    constructor() {
        owner = msg.sender;
    }

    function currentDay() public view returns (uint256) {
        return block.timestamp / DAY;
    }

    /// @notice Submit (or improve) your best score for today.
    /// @param name Display name, 1-16 characters.
    /// @param score Your game score (must beat your best today, if any).
    /// @param bnbMicro BNB coins collected, in micro-BNB.
    function submitScore(string calldata name, uint256 score, uint256 bnbMicro) external {
        require(bytes(name).length > 0 && bytes(name).length <= MAX_NAME, "name 1-16 chars");
        require(score > 0, "score 0");
        uint256 day = currentDay();
        require(score > bestScore[day][msg.sender], "beat your best first");

        bestScore[day][msg.sender] = score;

        // remove the player's old entry from today's board, if any
        uint256 count = topCount[day];
        uint256 oldPos = BOARD_SIZE;
        for (uint256 i = 0; i < count; i++) {
            if (_top[day][i].player == msg.sender) { oldPos = i; break; }
        }
        if (oldPos < BOARD_SIZE) {
            for (uint256 i = oldPos; i + 1 < count; i++) _top[day][i] = _top[day][i + 1];
            count -= 1;
        }

        // insert sorted, best first; keep only the top 10
        uint256 pos = count;
        while (pos > 0 && _top[day][pos - 1].score < score) pos -= 1;
        if (pos < BOARD_SIZE) {
            uint256 end = count < BOARD_SIZE ? count : BOARD_SIZE - 1;
            for (uint256 i = end; i > pos; i--) _top[day][i] = _top[day][i - 1];
            _top[day][pos] = Entry(msg.sender, name, score, bnbMicro);
            if (count < BOARD_SIZE) count += 1;
        }
        topCount[day] = count;

        emit ScoreSubmitted(day, msg.sender, name, score, bnbMicro);
    }

    function getTop(uint256 day) external view returns (Entry[10] memory board, uint256 count) {
        return (_top[day], topCount[day]);
    }

}
