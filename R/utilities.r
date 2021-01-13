#' Title
#' @details If `x` has any `NA`s, use `y`
#' @param x Value to check
#' @param y Backup value
#' @md
#' @return
#' @export
#' @seealso targets:::`%||NA%`
#'
#' @examples
if_not_na <- function (x, y) 
{
    if (anyNA(x)) {
        y
    }
    else {
        x
    }
}
