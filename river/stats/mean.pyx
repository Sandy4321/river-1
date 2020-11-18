cimport river.stats.base

from . import base
from . import summing


cdef class Mean(river.stats.base.Univariate):
    """Running mean.

    Parameters
    ----------
    mean
        Initial mean.
    n
        Initial sum of weights.

    Attributes
    ----------
    mean : float
        The current value of the mean.
    n : float
        The current sum of weights. If each passed weight was 1, then this is equal to the number
        of seen observations.

    Examples
    --------

    >>> from river import stats

    >>> X = [-5, -3, -1, 1, 3, 5]
    >>> mean = stats.Mean()
    >>> for x in X:
    ...     print(mean.update(x).get())
    -5.0
    -4.0
    -3.0
    -2.0
    -1.0
    0.0

    References
    ----------
    [^1]: [West, D. H. D. (1979). Updating mean and variance estimates: An improved method. Communications of the ACM, 22(9), 532-535.](https://people.xiph.org/~tterribe/tmp/homs/West79-_Updating_Mean_and_Variance_Estimates-_An_Improved_Method.pdf)
    [^2]: [Finch, T., 2009. Incremental calculation of weighted mean and variance. University of Cambridge, 4(11-5), pp.41-42.](https://fanf2.user.srcf.net/hermes/doc/antiforgery/stats.pdf)
    [^3]: [Chan, T.F., Golub, G.H. and LeVeque, R.J., 1983. Algorithms for computing the sample variance: Analysis and recommendations. The American Statistician, 37(3), pp.242-247.](https://amstat.tandfonline.com/doi/abs/10.1080/00031305.1983.10483115)
    """

    cpdef Mean update(self, double x, double w=1.):
        self.n += w
        if self.n > 0:
            self.mean += w * (x - self.mean) / self.n
        return self

    cpdef Mean revert(self, double x, double w=1.):
        self.n -= w
        if self.n < 0:
            raise ValueError('Cannot go below 0')
        elif self.n == 0:
            self.mean = 0.
        else:
            self.mean -= w * (x - self.mean) / self.n
        return self

    cpdef double get(self):
        return self.mean

    def __add__(self, Mean other):
        result = Mean()
        result.n = self.n + other.n
        result.mean = (self.n * self.mean + other.n * other.mean) / result.n

        return result


    def __iadd__(self, Mean other):
        cdef double old_n = self.n
        self.n += other.n
        self.mean = (old_n * self.mean + other.n * other.mean) / self.n

        return self

    def __sub__(self, Mean other):
        result = Mean()
        result.n = self.n - other.n

        if result.n > 0:
            result.mean = (self.n * self.mean - other.n * other.mean) / result.n
        else:
            result.n = 0.
            result.mean = 0.

        return result

    def __isub__(self, Mean other):
        cdef double old_n = self.n
        self.n -= other.n

        if self.n > 0:
            self.mean = (old_n * self.mean - other.n * other.mean) / self.n
        else:
            self.n = 0.
            self.mean = 0.

        return self

class RollingMean(summing.RollingSum):
    """Running average over a window.

    Parameters
    ----------
    window_size
        Size of the rolling window.

    Examples
    --------

    >>> from river import stats

    >>> X = [1, 2, 3, 4, 5, 6]

    >>> rmean = stats.RollingMean(window_size=2)
    >>> for x in X:
    ...     print(rmean.update(x).get())
    1.0
    1.5
    2.5
    3.5
    4.5
    5.5

    >>> rmean = stats.RollingMean(window_size=3)
    >>> for x in X:
    ...     print(rmean.update(x).get())
    1.0
    1.5
    2.0
    3.0
    4.0
    5.0

    """

    def get(self):
        return super().get() / len(self) if len(self) > 0 else 0


class BayesianMean(base.Univariate):
    """Estimates a mean using outside information.

    Parameters
    ----------
    prior
    prior_weight

    References
    ----------
    [^1]: [Additive smoothing](https://www.wikiwand.com/en/Additive_smoothing)
    [^2]: [Bayesian average](https://www.wikiwand.com/en/Bayesian_average)
    [^3]: [Practical example of Bayes estimators](https://www.wikiwand.com/en/Bayes_estimator#/Practical_example_of_Bayes_estimators)

    """

    def __init__(self, prior: float, prior_weight: float):
        self.prior = prior
        self.prior_weight = prior_weight
        self.mean = Mean()

    @property
    def name(self):
        return 'bayes_mean'

    def update(self, x):
        self.mean.update(x)
        return self

    def get(self):

        # Uses the notation from https://www.wikiwand.com/en/Bayes_estimator#/Practical_example_of_Bayes_estimators
        R = self.mean.get()
        v = self.mean.n
        m = self.prior_weight
        C = self.prior

        return (R * v + C * m) / (v + m)