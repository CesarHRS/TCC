#include "dynbits.h"

DynBits::DynBits(size_t nbits) : data((nbits + CHUNK_BITS - 1) / CHUNK_BITS) {}

void DynBits::set_bit(size_t i, bool v) {
    size_t idx = i / CHUNK_BITS;
    size_t off = i % CHUNK_BITS;
    if (v) data[idx] |= (chunk_t(1) << off);
    else data[idx] &= ~(chunk_t(1) << off);
}

void DynBits::flip(size_t i) {
    size_t idx = i / CHUNK_BITS;
    size_t off = i % CHUNK_BITS;
    data[idx] ^= (chunk_t(1) << off);
}

bool DynBits::test(size_t i) const {
    size_t idx = i / CHUNK_BITS;
    size_t off = i % CHUNK_BITS;
    return (data[idx] >> off) & 1u;
}

size_t DynBits::count() const {
    size_t s = 0;
    for (chunk_t v : data) s += __builtin_popcountll(v);
    return s;
}

std::string DynBits::to_string(size_t nbits) const {
    std::string out;
    out.reserve(nbits);
    for (size_t i = 0; i < nbits; ++i) out.push_back(test(i) ? '1' : '0');
    return out;
}