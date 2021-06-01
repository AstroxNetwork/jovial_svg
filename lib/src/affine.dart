/*
MIT License

Copyright (c) 2021 William Foote

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

library jovial_svg.matrix;

import 'dart:math';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';
import 'package:quiver/core.dart' as quiver;

abstract class Affine {
  Affine._p();

  ///
  /// Create a new immutable matrix as a view on underlying storage with an
  /// offset.  The first two rows are taken from storage, in row major order;
  /// the final row of "0 0 1" is implicit.  The storage must have a length
  /// of at least offset + 6.  The caller must ensure that the underlying list
  /// is not changed.
  ///
  factory Affine.fromCompact(List<double> storage, int offset) =>
      _CompactAffine(storage, offset);

  void copyIntoCompact(List<double> storage, [int offset = 0]);

  double get(int row, int col);
  double _get(int row, int col);

  ///
  /// Give the 4x4 column-major matrix that Canvas wants
  ///
  Float64List get forCanvas {
    final r = Float64List(16);
    r[15] = 1;
    int p = 0;
    for (int col = 0; col < 2; col++) {
      for (int row = 0; row < 3; row++) {
        r[p++] = get(row, col);
      }
      p++;
    }
    p += 2;
    r[p++] = 1;
    p++;
    for (int row = 0; row < 2; row++) {
      r[p++] = get(row, 2);
    }
    return r;
  }

  MutableAffine get toMutable;
  MutableAffine mutableCopy();
  Affine get toKey;

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write('Affine:\n');
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        sb.write('\t${get(r, c)}');
      }
      sb.write('\n');
    }
    return sb.toString();
  }

  Point<double> transformed(Point<double> p) => Point(
      p.x * _get(0, 0) + p.y * _get(0, 1) + _get(0, 2),
      p.x * _get(1, 0) + p.y * _get(1, 1) + _get(1, 2));

  @override
  int get hashCode => quiver.hash4(_get(0, 0), _get(0, 1), _get(0, 2),
      quiver.hash3(_get(1, 0), _get(1, 1), _get(1, 2)));

  @override
  bool operator ==(Object other) => _equals(other);

  bool _equals(Object other) {
    if (identical(this, other)) {
      return true;
    } else if (other is Affine) {
      for (int c = 0; c < 3; c++) {
        for (int r = 0; r < 2; r++) {
          if (_get(r, c) != other._get(r, c)) {
            return false;
          }
        }
      }
      return true;
    } else {
      return false;
    }
  }
}

class _CompactAffine extends Affine {
  final List<double> _storage;
  final int _offset;

  _CompactAffine(this._storage, this._offset) : super._p() {
    assert(_storage.length >= _offset + 6);
  }

  ///
  /// Copy the six values of this matrix into storage starting at offset,
  /// in row major order.
  ///
  @override
  void copyIntoCompact(List<double> storage, [int offset = 0]) => storage
      .setRange(offset, offset + 6, _storage.getRange(_offset, _offset + 6));

  @override
  double _get(int row, int column) {
    assert(row >= 0 && row < 3 && column >= 0 && column < 3);
    if (row == 2) {
      if (column == 2) {
        return 1;
      } else {
        return 0;
      }
    } else {
      return _storage[_offset + _storageIndex(row, column)];
    }
  }

  static int _storageIndex(int row, int column) => row * 3 + column;

  void _checkIndices(int row, int col) {
    if (row < 0 || row > 2) {
      throw IndexError(row, this);
    } else if (col < 0 || col > 2) {
      throw IndexError(row, this);
    }
  }

  @override
  double get(int row, int col) {
    _checkIndices(row, col);
    return _get(row, col);
  }

  @override
  bool _equals(Object other) {
    if (other is _CompactAffine &&
        identical(_storage, other._storage) &&
        _offset == other._offset) {
      return true;
    } else {
      return super._equals(other);
    }
  }

  @override
  MutableAffine get toMutable {
    final storage = Matrix3.zero();
    for (int c = 0; c < 3; c++) {
      for (int r = 0; r < 3; r++) {
        storage.setEntry(r, c, get(r, c));
      }
    }
    return MutableAffine(storage);
  }

  @override
  MutableAffine mutableCopy() => toMutable;

  @override
  Affine get toKey => this;
}

class MutableAffine extends Affine {
  final Matrix3 _storage;

  MutableAffine([Matrix3? storage])
      : _storage = storage ?? Matrix3.zero(),
        super._p();

  MutableAffine.identity()
      : _storage = Matrix3.identity(),
        super._p();

  MutableAffine.scale(double sx, double sy)
      : _storage = Matrix3.zero(),
        super._p() {
    set(0, 0, sx);
    set(1, 1, sy);
    set(2, 2, 1);
  }

  MutableAffine.translation(double tx, double ty)
      : _storage = Matrix3.identity(),
        super._p() {
    set(0, 2, tx);
    set(1, 2, ty);
  }

  MutableAffine.rotation(double a)
      : _storage = Matrix3.zero(),
        super._p() {
    final c = cos(a);
    final s = sin(a);
    set(0, 0, c);
    set(0, 1, -s);
    set(1, 0, s);
    set(1, 1, c);
    set(2, 2, 1);
  }

  MutableAffine.skewX(double a)
      : _storage = Matrix3.identity(),
        super._p() {
    set(0, 1, tan(a));
  }

  MutableAffine.skewY(double a)
      : _storage = Matrix3.identity(),
        super._p() {
    set(1, 0, tan(a));
  }

  MutableAffine.copy(MutableAffine other)
      : _storage = Matrix3.copy(other._storage),
        super._p();

  MutableAffine.cssTransform(List<double> css)
      : _storage = Matrix3.zero(),
        super._p() {
    // s. 7.5 https://www.w3.org/TR/SVGTiny12/coords.html
    set(0, 0, css[0]);
    set(1, 0, css[1]);
    set(0, 1, css[2]);
    set(1, 1, css[3]);
    set(0, 2, css[4]);
    set(1, 2, css[5]);
    set(2, 2, 1);
  }

  void set(int row, int col, double v) => _storage.setEntry(row, col, v);

  void multiplyBy(MutableAffine other) => _storage.multiply(other._storage);

  ///
  /// Find the inverse of this matrix.  Caller should ensure determinant
  /// isn't too close to zero.
  ///
  void invert() => _storage.invert();

  double determinant() => _storage.determinant();

  bool isIdentity() => _storage.isIdentity();

  @override
  double _get(int row, int col) => _storage.entry(row, col);

  @override
  double get(int row, int col) => _get(row, col);

  @override
  void copyIntoCompact(List<double> storage, [int offset = 0]) {
    for (int col = 0; col < 3; col++) {
      for (int row = 0; row < 2; row++) {
        storage[offset + _CompactAffine._storageIndex(row, col)] =
            _get(row, col);
      }
    }
  }

  @override
  Affine get toKey {
    final storage = Float64List(6);
    copyIntoCompact(storage);
    return _CompactAffine(storage, 0);
  }

  @override
  MutableAffine get toMutable => this;

  @override
  MutableAffine mutableCopy() => MutableAffine.copy(this);
}
