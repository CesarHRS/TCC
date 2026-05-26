#ifndef CONFIG_H
#define CONFIG_H

#include <cstddef>

#ifndef BITS
#define BITS 1024
#endif

static constexpr size_t N_BITS = BITS;

#include <vector>
#include <cstdint>

using chunk_t = uint64_t;
static constexpr size_t CHUNK_BITS = sizeof(chunk_t) * 8;

#endif // CONFIG_H