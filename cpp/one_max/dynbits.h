#ifndef DYNBITS_H
#define DYNBITS_H

#include "config.h"
#include <vector>
#include <string>

struct DynBits {
    std::vector<chunk_t> data;
    DynBits(size_t nbits = N_BITS);
    void set_bit(size_t i, bool v);
    void flip(size_t i);
    bool test(size_t i) const;
    size_t count() const;
    std::string to_string(size_t nbits = N_BITS) const;
};

#endif // DYNBITS_H