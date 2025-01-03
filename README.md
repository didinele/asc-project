# system-arch-project

See the project [here](https://cs.unibuc.ro/~crusu/asc/Arhitectura%20Sistemelor%20de%20Calcul%20(ASC)%20-%20Tema%20Laborator%202024.pdf) (Romanian).

This was worth 10% of the final grade.

# Vector

```sh
gcc -g -m32 vector.S -o task1
```

Useful for debugging:
```
print/u *(unsigned char[1024])blocks@1024
```

# Matrix

```sh
gcc -g -m32 matrix.S -o task2
```

Official tests live [here](https://github.com/iancuivasciuc/csa/tree/master), within the `project` directory.

The compiled `task1` and `task2` are to be moved into a local copy of the above repo, within the `project` directory,
and `python3 checker.py` is to be ran.

At this time, this solution gets a full score on the official tests. The `CONCRETE` op has no official tests,
but it is implemented and tested locally.

For submission, I ultimately compiled with:
```sh
$ gcc -no-pie -m32 vector.S -o task1
$ gcc -no-pie -m32 matrix.S -o task2
```

`-no-pie` was probably correct for the local debug builds too, but I didn't really care for it/it ran fine without.

Final grade: ?/100.

Note that despite the commit history, this repository only went public on 2025-01-06, AFTER the deadline (midnight of 2025-01-05).
