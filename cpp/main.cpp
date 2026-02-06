#include "config.h"
#include <chrono>
#include <iostream>
#include <thread>
#include <vector>
#include <mutex>
#include "dynbits.h"
#include "hill_climbing.h"
#include <random>

int main(int argc, char **argv) {
#ifdef USE_THREADS
    const size_t num_threads = NUM_THREADS;
#else
    const size_t num_threads = 1;
#endif

    if (num_threads == 1) {
        std::cout << "Usando 1 thread (single-core)." << std::endl;
    } else {
        std::cout << "Usando " << num_threads << " threads." << std::endl;
    }

#ifdef USE_THREADS

    std::vector<std::thread> threads;
    std::vector<DynBits> results(num_threads);
    std::mutex results_mutex;

    auto worker = [&](size_t thread_id) {
        std::random_device rd;
        size_t seed = rd();
        DynBits best = run_hill_climbing(seed);
        std::lock_guard<std::mutex> lock(results_mutex);
        results[thread_id] = best;
    };

    auto start_time = std::chrono::high_resolution_clock::now();

    for (size_t i = 0; i < num_threads; ++i) {
        threads.emplace_back(worker, i);
    }

    for (auto &t : threads) {
        t.join();
    }

    // Find the best among all threads
    DynBits overall_best = results[0];
    size_t overall_best_fitness = calculate_fitness(overall_best);
    for (const auto &res : results) {
        size_t fit = calculate_fitness(res);
        if (fit > overall_best_fitness) {
            overall_best = res;
            overall_best_fitness = fit;
        }
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::micro> elapsed = end_time - start_time;

    std::cout << "Tempo = " << elapsed.count() << " µs" << std::endl;
#else
    std::random_device rd;
    size_t seed = rd();
    auto start_time = std::chrono::high_resolution_clock::now();
    DynBits best = run_hill_climbing(seed);
    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::micro> elapsed = end_time - start_time;
    std::cout << "Tempo = " << elapsed.count() << " µs" << std::endl;
#endif

    return 0;
}
