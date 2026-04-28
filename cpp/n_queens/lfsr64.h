#ifndef LFSR64_H
#define LFSR64_H

#include <cstdint>

class LFSR64 {
private:
    uint64_t state;

    static constexpr uint64_t TAP_63 = 1ULL << 63;
    static constexpr uint64_t TAP_62 = 1ULL << 62;
    static constexpr uint64_t TAP_60 = 1ULL << 60;
    static constexpr uint64_t TAP_59 = 1ULL << 59;

public:
    explicit LFSR64(uint64_t seed = 0x123456789ABCDEFULL) : state(seed) {
        if (state == 0) {
            state = 0x123456789ABCDEFULL;
        }
    }

    uint64_t next() {
        // Extract feedback from the taps
        uint64_t feedback = ((state & TAP_63) >> 63) ^
                           ((state & TAP_62) >> 62) ^
                           ((state & TAP_60) >> 60) ^
                           ((state & TAP_59) >> 59);

        // Shift right and insert feedback at MSB
        state = (state >> 1) | (feedback << 63);

        return state;
    }

    uint32_t nextRange(uint32_t max) {
        if (max == 0) return 0;
        return next() % max;
    }

    uint64_t getState() const {
        return state;
    }

    void setState(uint64_t newState) {
        if (newState == 0) {
            state = 0x123456789ABCDEFULL;
        } else {
            state = newState;
        }
    }
};

#endif // LFSR64_H
