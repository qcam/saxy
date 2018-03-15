# Benchmarking Saxy

```
Operating System: macOS
CPU Information: Intel(R) Core(TM) i5-5257U CPU @ 2.70GHz
Number of Available Cores: 4
Available memory: 8 GB
Elixir 1.6.1
Erlang 20.2.2
Benchmark suite executing with the following configuration:
warmup: 2 s
time: 10 s
parallel: 1
inputs: none specified
Estimated total run time: 24 s
```

## SAX binary XML parsing

### Hackernoon

```
Name             ips        average  deviation         median         99th %
saxy          437.79        2.28 ms     ±8.48%        2.22 ms        3.21 ms
erlsom        275.23        3.63 ms    ±16.01%        3.71 ms        5.03 ms

Comparison:
saxy          437.79
erlsom        275.23 - 1.59x slower
```

### Reddit RSS

```
Name             ips        average  deviation         median         99th %
saxy          582.05        1.72 ms    ±12.19%        1.65 ms        2.80 ms
erlsom        386.85        2.59 ms    ±18.56%        2.69 ms        4.12 ms

Comparison:
saxy          582.05
erlsom        386.85 - 1.50x slower
```

### Soccer (1.1MB XML file)

```
Name             ips        average  deviation         median         99th %
saxy           15.37       65.08 ms     ±5.36%       64.98 ms       76.18 ms
erlsom          3.53      283.09 ms     ±1.28%      282.47 ms      294.30 ms

Comparison:
saxy           15.37
erlsom          3.53 - 4.35x slower
```

## Simple Form parsing

### Hackernoon

```
Name             ips        average  deviation         median         99th %
saxy          421.99        2.37 ms     ±9.78%        2.29 ms        3.72 ms
erlsom        286.80        3.49 ms    ±15.11%        3.79 ms        4.46 ms

Comparison:
saxy          421.99
erlsom        286.80 - 1.47x slower
```

### Reddit RSS

```
Name             ips        average  deviation         median         99th %
saxy          565.88        1.77 ms    ±12.68%        1.70 ms        2.98 ms
erlsom        409.14        2.44 ms    ±22.06%        2.24 ms        4.11 ms

Comparison:
saxy          565.88
erlsom        409.14 - 1.38x slower
```

### Soccer (1.1MB XML file)

```
Name             ips        average  deviation         median         99th %
saxy           14.09       70.96 ms     ±5.30%       70.90 ms       77.98 ms
erlsom          3.05      327.58 ms     ±1.18%      327.04 ms      337.97 ms

Comparison:
saxy           14.09
erlsom          3.05 - 4.62x slower
```
