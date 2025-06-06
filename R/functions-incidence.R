#' @importFrom magrittr %>% %<>%
#' @importFrom rlang enquo as_string quo_name
#' @importFrom nplyr nest_mutate
#' @importFrom purrr pmap
#' @import tibble
#' @import dplyr

NULL

#' Calculate incidence
#'
#' A function to calculate the incidence per given time period, such as per week.
#'
#' @param d_ostrc a dateframe with OSTRC questionnaire responses
#' @param id_participant vector within `d_ostrc` that identifies
#'                       a person, athlete, participant, etc.
#' @param time vector within `d_ostrc` that identifies a time period,
#'             such as a vector of dates or week-numbers. The incidences will be calculated per
#'             value of this vector, such as per week.
#' @param hp_type a binary vector within `d_ostrc` which classifies a type of health problem as 1,
#'                and anything that is not the type of health problem as 0.
#'                This can be health problem (1/0), injury (1/0),
#'                illness (1/0), acute injury (1/0) or any other health problem type that the user wishes
#'                to calculate the incidence on.
#' @examples
#' library(tidyr)
#' d_ostrc <- tribble(
#'   ~id_participant, ~day_nr, ~hp,
#'   1, 1, 1,
#'   1, 1, 1,
#'   1, 2, 0,
#'   1, 3, 1,
#'   2, 1, 1,
#'   2, 2, 0,
#'   2, 3, 1
#' )
#' calc_incidence(d_ostrc, id_participant, week_nr, hp)
#' @export
calc_incidence <- function(d_ostrc, id_participant, time, hp_type) {
  options(dplyr.summarise.inform = FALSE)

  id_participant <- enquo(id_participant)
  time <- enquo(time)
  time_name <- rlang::as_string(quo_name(time))
  hp_type <- enquo(hp_type)
  hp_type_name <- rlang::as_string(quo_name(hp_type))

  id_participant_values <- d_ostrc %>% pull(!!id_participant)
  time_values <- d_ostrc %>% pull(!!time)
  hp_type_values <- d_ostrc %>% pull(!!hp_type)

  if (all(is.na(id_participant_values)) |
    all(is.na(time_values)) |
    all(is.na(hp_type_values))
  ) {
    stop("One of the input variables has only missing NA observations.")
  }

  if (!is.numeric(hp_type_values)) {
    stop(
      paste0(
        "Variable ",
        hp_type_name,
        " is not numeric or integer. Make sure ",
        hp_type_name,
        " is a binary variable of class numeric or integer."
      )
    )
  }

  if (!all(unique(hp_type_values) %in% c(0, 1, NA))) {
    stop(
      paste0(
        "Variable ",
        hp_type_name,
        " has more than two possible values. Make sure ",
        hp_type_name,
        " is a binary variable coded only with 0 and 1, or with NA for missing."
      )
    )
  }

  if (length(unique(time_values)) == 1) {
    stop(
      paste0(
        "Variable ",
        time_name,
        " has only one value. Are you sure this is the time period of interest?"
      )
    )
  }

  if (length(unique(na.omit(hp_type_values))) == 1) {
    warning("The incidence of ", hp_type_name, " is constant.")
  }

  # Missing time points won't be included,
  # and missing hp_types won't be included
  d_nonmissing <- d_ostrc %>% filter(!is.na(!!time), !is.na(!!hp_type))

  # consider multiple health problems as just 1
  d_hp_type_per_id_per_time <- d_nonmissing %>%
    group_by(!!id_participant, !!time) %>%
    summarise(hp_type_n = sum(!!hp_type, na.rm = TRUE)) %>%
    mutate(hp_type_atleast1 = ifelse(hp_type_n > 0, 1, 0)) %>%
    ungroup()

  # find out if previous time period had a 1 or 0
  d_hp_type_per_id_per_time <-
    d_hp_type_per_id_per_time %>%
    group_by(!!id_participant) %>%
    mutate(
      previous_time_status = lag(hp_type_atleast1),
      new_case = case_when(
        previous_time_status == 0 & hp_type_atleast1 == 1 ~ 1,
        previous_time_status == 1 ~ 0,
        hp_type_atleast1 == 0 ~ 0,
        is.na(previous_time_status) & hp_type_atleast1 == 1 ~ NA_real_
      )
    ) %>%
    ungroup()

  # different calculation if it is the first timepoint of data or not
  d_first_time <- d_hp_type_per_id_per_time %>% filter(!!time == min(!!time))
  d_rest_time <- d_hp_type_per_id_per_time %>% filter(!!time != min(!!time))

  # calculate incidence
  d_incidence_firsttime <- d_first_time %>%
    group_by(!!time) %>%
    summarise(
      n_responses = n(),
      n_new_cases = sum(new_case),
      inc_cases = ifelse(n_new_cases == 0, 0, NA)
    ) %>%
    ungroup()

  d_incidence_resttime <- d_rest_time %>%
    group_by(!!time) %>%
    summarise(
      n_responses = n(),
      n_new_cases = sum(new_case, na.rm = TRUE),
      inc_cases = n_new_cases / n_responses
    ) %>%
    ungroup()

  d_incidence <- bind_rows(d_incidence_firsttime, d_incidence_resttime)
  d_incidence
}

#' Calculate incidence mean
#'
#' A function to calculate the mean incidence per given time period, such as per week.
#'
#' @param d_ostrc a dateframe with OSTRC questionnaire responses
#' @param id_participant vector within `d_ostrc` that identifies
#'                       a person, athlete, participant, etc.
#' @param time vector within `d_ostrc` that identifies a time period,
#'             such as a vector of dates or week-numbers. The incidences will be calculated per
#'             value of this vector, such as per week.
#'             Then, the mean of these incidences will be calculated, resulting in a single number.
#' @param hp_type a binary vector within `d_ostrc` which classifies a type of health problem as 1,
#'                and anything that is not the type of health problem as 0.
#'                This can be health problem (1/0), injury (1/0),
#'                illness (1/0), acute injury (1/0) or any other health problem type that the user wishes
#'                to calculate the incidence of.
#' @param ci_level The level of the confidence intervals. Default is 0.95 for 95% confidence intervals.
#' @examples
#' library(tidyr)
#' d_ostrc <- tribble(
#'   ~id_participant, ~week_nr, ~hp,
#'   1, 1, 1,
#'   1, 1, 1,
#'   1, 2, 0,
#'   2, 1, 0,
#'   2, 2, 1,
#'   3, 1, 0,
#'   3, 2, 0
#' )
#' calc_incidence_mean(d_ostrc, id_participant, week_nr, hp)
#' @export
calc_incidence_mean <- function(d_ostrc, id_participant, time, hp_type, ci_level = 0.95) {
  options(dplyr.summarise.inform = FALSE)

  id_participant <- enquo(id_participant)
  time <- enquo(time)
  hp_type <- enquo(hp_type)

  d_incidence <- calc_incidence(d_ostrc, !!id_participant, !!time, !!hp_type)

  # calc incidences
  d_incmean <- d_incidence %>%
    summarise(
      inc_mean = mean(inc_cases, na.rm = TRUE),
      inc_sd = sd(inc_cases, na.rm = TRUE)
    )

  # calc CIs
  count <- nrow(d_incidence)
  se <- sd(d_incidence$inc_cases, na.rm = TRUE) / sqrt(count)
  ci_lower <- mean(d_incidence$inc_cases, na.rm = TRUE) - (qt(1 - ((1 - ci_level) / 2), count - 1) * se)
  ci_upper <- mean(d_incidence$inc_cases, na.rm = TRUE) + (qt(1 - ((1 - ci_level) / 2), count - 1) * se)

  d_incmean <- d_incmean %>% mutate(inc_ci_lower = ci_lower, inc_ci_upper = ci_upper)
  d_incmean
}

#' Calculate incidence all
#'
#' A function to calculate the mean incidence for each health problem type
#' given in a vector of health problems types. For instance, to provide the
#' incidence of health problems, substantial health problems, injuries, substantial injuries,
#' contact vs. noncontact injuries and so on.
#' Uses `calc_incidence_mean` to calculate for each type.
#'
#' @param d_ostrc a dateframe with OSTRC questionnaire responses
#' @param id_participant vector within `d_ostrc` that identifies
#'                       a person, athlete, participant, etc.
#' @param time vector within `d_ostrc` that identifies a time period,
#'             such as a vector of dates or week-numbers. The incidences will be calculated per
#'             value of this vector, such as per week.
#'             Then, the mean of these incidences will be calculated, resulting in a single number.
#' @param hp_types a vector of strings representing variable names of
#'                health problem variables within `d_ostrc`. These variables must classify a
#'                type of health problem as 1,
#'                and anything that is not the type of health problem as 0.
#'                This can be health problem (1/0), injury (1/0),
#'                illness (1/0), acute injury (1/0) or any other health problem type that the user wishes
#'                to calculate the incidence of.
#' @param group Optional. A strins representing a variable name of
#'                a variable within `d_ostrc`. The variable must be
#'                class categorical or factor. Examples are "season", "gender" etc.
#'                Output will be calculated per subgroup.
#' @param ci_level The level of the confidence intervals. Default is 0.95 for 95% confidence intervals.
#' @examples
#' library(tidyr)
#' d_ostrc <- tribble(
#'   ~id_participant, ~week_nr, ~hp, ~hp_sub, ~season,
#'   1, 1, 1, 0, 1,
#'   1, 2, 1, 1, 1,
#'   1, 3, 0, 0, 1,
#'   2, 1, 1, 1, 1,
#'   2, 2, 1, 1, 1,
#'   3, 1, 0, 0, 1,
#'   3, 2, 0, 0, 1,
#'   1, 1, 1, 0, 2,
#'   1, 2, 1, 0, 2,
#'   1, 3, 0, 0, 2,
#'   2, 1, 1, 0, 2,
#'   2, 2, 1, 0, 2,
#'   3, 1, 1, 1, 2,
#'   3, 2, 1, 1, 2
#' )
#' hp_types_vector <- c("hp", "hp_sub")
#' calc_incidence_all(d_ostrc, id_participant, week_nr, hp_types_vector)
#' @export
calc_incidence_all <- function(d_ostrc, id_participant, time, hp_types, group = NULL, ci_level = 0.95) {
  options(dplyr.summarise.inform = FALSE)

  id_participant <- enquo(id_participant)
  time <- enquo(time)
  hp_types_syms <- syms(hp_types)

  if (is.null(group)) {
    l_incidences <- list()
    for (i in 1:length(hp_types)) {
      l_incidences[[i]] <- calc_incidence_mean(d_ostrc, !!id_participant, !!time, !!hp_types_syms[[i]], ci_level)
      l_incidences[[i]] <- l_incidences[[i]] %>% mutate(hp_type = hp_types[[i]])
    }
    d_incidences <- bind_rows(l_incidences)
    d_incidences %<>% select(hp_type, starts_with("inc"))
  } else {
    group <- syms(group)
    d_nested <- d_ostrc %>%
      group_by(!!!group) %>%
      nest()
    n_groups <- length(d_nested$data)
    d_grouping_var <- d_nested %>%
      select(-data) %>%
      ungroup()
    var_name <- names(d_grouping_var)

    for (i in 1:length(d_nested$data)) {
      group_id <- d_grouping_var %>%
        slice(i) %>%
        pull()
      d_nested$data[[i]][var_name] <- rep(
        group_id,
        nrow(d_nested$data[[i]])
      )
    }

    l_datasets <- rep(d_nested$data, length(hp_types_syms))
    l_hp_types <- rep(hp_types_syms, n_groups)
    l_hp_names <- rep(as.list(hp_types), n_groups)

    pos <- match(l_hp_types, hp_types_syms)
    pos_wanted <- sort(pos)
    l_hp_types <- l_hp_types[pos_wanted]
    l_hp_names <- l_hp_names[pos_wanted]

    list_of_lists <- list(x = l_hp_types, y = l_datasets, z = l_hp_names)

    d_incidences <- purrr::pmap(
      list_of_lists,
      function(x, y, z) {
        d_incs <- calc_incidence_mean(y, !!id_participant, !!time, !!x) %>%
          mutate(hp_type = z)

        d_incs[var_name] <- y[var_name][1, ]
        d_incs
      }
    ) %>% bind_rows()
    d_incidences %<>% select(all_of(var_name), hp_type, starts_with("inc"))
  }
  d_incidences
}
