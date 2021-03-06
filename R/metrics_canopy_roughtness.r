# ===============================================================================
#
# PROGRAMMERS:
#
# jean-romain.roussel.1@ulaval.ca  -  https://github.com/Jean-Romain/lidR
#
# COPYRIGHT:
#
# Copyright 2016 Jean-Romain Roussel
#
# This file is part of lidR R package.
#
# lidR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# ===============================================================================

# fractal_dimension
#
# Computes the fractal dimension of a surface. The fractal dimension is a measure
# of roughness.
#
# Fractal dimension computes the roughness based on the box counting method (see Taud and Parrot).
# If the input has an NA value, it returns NA. If the input is too small it returns NA.
# If the input matrix is not a square matrix, the function cuts the input matrix to create a square matrix.
# @param mtx numeric matrix that is the representation of a surface model
# @return numeric. A number between 0 and 3. 3 being the dimension of a volume
# @references Taud, H., & Parrot, J.-F. (2005). Mesure de la rugosite des MNT a l'aide de la dimension fractale. Geomorphologie : Relief, Processus, Environnement, 4, 327-338. http://doi.org/10.4000/geomorphologie.622
# @examples
# mtx = matrix(runif(100), 10, 10)
# fractal_dimension(mtx)
# @export fractal_dimension
fractal_dimension = function(x, plot = FALSE)
{
  if (is(x, "RasterLayer"))
    x = raster::as.matrix(x)
  else if (!is.matrix(x))
    stop("fractal_dimension: mtx should be a RasterLayer or a Matrix", call. = FALSE)

  mtx = x

  if ( sum(is.na(mtx)) > 0 )
    return(NA_real_)

  size = min(dim(mtx))

  if ( size < 6)
    return(NA_real_)

  size = ifelse(size %% 2 == 0, size, size - 1)

  mtx = mtx[1:size, 1:size]

  q = 1:size
  q = q[size %% q == 0]

  if (length(q) < 3)
    return(as.numeric(NA))

  nbbox = sapply(q, countBox, mtx = mtx)

  lm = stats::lm(log(nbbox) ~ log(q))

  if (plot)
  {
    graphics::plot(log(nbbox) ~ log(q))
    graphics::abline(lm)
  }

  return(abs(as.numeric(stats::coefficients(lm)[2])))
}

countBox = function(q, mtx)
{
	  rg  <- (row(mtx) - 1) %/% q + 1
    cg  <- (col(mtx) - 1) %/% q + 1
    rci <- (rg - 1) * max(cg) + cg
    N   <- prod(dim(mtx))/(q^2)

	  clip = lapply(1:N, function(x) mtx[rci == x])
	  box = sapply(clip, max)/q

	  return(sum(box))
}


#' Rumple index of roughness
#'
#' Computes the roughness of a surface as the ratio between the area of a surface and its
#' projected area on the ground. For each type of input the function makes a Delaunay
#' triangulation of the points and computes the ratio between the area of the triangles and
#' the area or the convexhull (i.e. the projected area of the triangles on the X-Y plane).
#'
#' @param x A 'RasterLayer' or a 'lasmetrics' object, or a vector of x point coordinates.
#' @param y numeric. If \code{x} is a vector of coordinates: the associated y coordinates.
#' @param z numeric. If \code{x} is a vector of coordinates: the associated z coordinates.
#' @param ... unused
#'
#' @return numeric. The computed Rumple index.
#'
#' @export
#' @examples
#' x = runif(20, 0, 100)
#' y = runif(20, 0, 100)
#'
#' # Perfectly flat surface, rumple_index = 1
#' z = rep(10, 20)
#' rumple_index(x, y, z)
#'
#' # Rough surface, rumple_index > 1
#' z = runif(20, 0, 10)
#' rumple_index(x, y, z)
#'
#' # Rougher surface, rumple_index increases
#' z = runif(20, 0, 50)
#' rumple_index(x, y, z)
#'
#' # Measure of roughness is scale dependent
#' rumple_index(x, y, z)
#' rumple_index(x/10, y/10, z)
#'
#' # Use with a canopy height model
#' LASfile <- system.file("extdata", "Megaplot.laz", package="lidR")
#' las = readLAS(LASfile)
#' chm = las %>% grid_canopy
#' rumple_index(chm)
rumple_index <- function(x, y = NULL, z = NULL, ...)
{
  xtxt   = lazyeval::expr_text(x)
  ytxt   = lazyeval::expr_text(y)
  ztxt   = lazyeval::expr_text(z)

  if (is(x, "RasterLayer"))
  {
    p = raster::rasterToPoints(x)
    x = p[, 1]
    y = p[, 2]
    z = p[, 3]
    option = "Qz"
  }
  else if (is(x, "lasmetrics"))
  {
    p = x
    x = p$X
    y = p$Y
    z = p[, 3] %>% unlist
    option = "Qz"
  }
  else if (is.numeric(x) & is.numeric(y) & is.numeric(z))
  {
    if (length(x) != length(y))
      stop(paste0(xtxt, " is not same length as ", ytxt), call. = FALSE)

    if (length(x) != length(z))
      stop(paste0(xtxt, " is not same length as ", ztxt), call. = FALSE)

    option = ""
  }
  else
    stop("No method for inputs", call. = FALSE)

  keep = !is.na(z)
  x = x[keep]
  y = y[keep]
  z = z[keep]

  return(rumple_index_internal(x,y,z, option))
}

# rumple_index_raster = function(x, res)
# {
#   x = cbind(0, x)
#   x = rbind(0, x)
#
#   r = raster::raster(x)
#
#   kernel = matrix(rep(0,9), ncol = 3)
#   kernel[2,2] = 2
#   kernel[2,3] = -1
#   kernel[3,2] = -1
#
#   y = raster::focal(r, w = kernel, fun = sum, na.rm = TRUE)
#   y = raster::as.matrix(y)
#   y = y[,-1]
#   y = y[-1,]
#   y[, dim(y)[2]] = 0
#   y[dim(y)[1], ] = 0
#   y[is.na(x)] = NA
#   y = abs(y)
#
#   z = res^2 + res*y
#
#   return( sum(z, na.rm = T)/(sum(!is.na(z))*res^2) )
# }

rumple_index_internal = function(x,y,z, options = "")
{
  if (length(x) != length(y) | length(x) != length(z))
    stop("Different lengths for x,y,z", call. = FALSE)

  keep = !(is.na(x) | is.na(y) | is.na(z))
  x = x[keep]
  y = y[keep]
  z = z[keep]

  X = cbind(x,y,z)
  dn = suppressMessages(geometry::delaunayn(X[,1:2], options = options))
  N = tinfo(dn, X)

  area  = sum(N[,5])
  parea = sum(N[,6])
  rumple = area/parea

  return(rumple)
}