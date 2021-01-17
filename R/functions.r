#' Title
#' @details A new token is needed every hour, so might as well run it every time
#' @param api_key Key from Ecobee, need to sign up as developer
#' @param refresh_token Gotten from Ecobee, good for a year
#'
#' @return A character token
#' @export
#'
#' @examples
#' access_token <- get_token(api_key=Sys.getenv('ECOBEE_API_KEY'), refresh_token=Sys.getenv('ECOBEE_REFRESH_TOKEN'))
get_token <- function(
    api_key=Sys.getenv('ECOBEE_API_KEY'), 
    refresh_token=Sys.getenv('ECOBEE_REFRESH_TOKEN'),
    refresh_url='https://api.ecobee.com/token'
)
{
    token_request <- httr::POST(
        url=glue::glue("{refresh_url}?grant_type=refresh_token&code={refresh_token}&client_id={api_key}"), 
        encode='json'
    )
    
    return(httr::content(token_request)$access_token)
}


#' Title
#' @details Calls the Ecobee API to get a report about the thermostat and sensors
#' @param startDate 
#' @param endDate 
#' @param thermostats 
#' @param access_token 
#'
#' @return
#' @export
#'
#' @examples
#' the_report <- get_report(thermostats='id1,id2', access_token=access_token)
get_report <- function(
    startDate=as.character(Sys.Date()), endDate=as.character(Sys.Date()), 
    startInterval=0, endInterval=287,
    thermostats, 
    access_token
)
{
    httr::GET(
        glue::glue(
            'https://api.ecobee.com/1/runtimeReport?format=json&body={{"startDate":"{startDate}","endDate":"{endDate}","startInterval":{startInterval},"endInterval":{endInterval},"columns":"zoneAveTemp,hvacMode,fan,outdoorTemp,outdoorHumidity,sky,wind,zoneClimate,zoneCoolTemp,zoneHeatTemp,zoneHvacMode,zoneOccupancy","selection":{{"selectionType":"thermostats","selectionMatch":"{thermostats}"}},"includeSensors":true}}'
        )
        , httr::add_headers(Authorization=glue::glue('Bearer {access_token}'))
        , encode='json'
    ) %>% 
        httr::content()
}


#' Title
#' @details The column names are kept separate from the data so this is used to tie things together
#' @param sensors 
#'
#' @return
#' @export
#'
#' @examples
#' relate_sensor_id_to_name(report$sensorList[[1]]$sensors)
relate_sensor_id_to_name <- function(sensors)
{
    purrr::map_df(
        sensors, 
        ~tibble::tibble(ID=.x$sensorId, name=glue::glue('{.x$sensorName}_{.x$sensorType}'))
    )
}


#' Title
#' @details The column names are kept separate from the data so this is used to tie things together
#' @param sensorInfo 
#'
#' @return
#' @export
#'
#' @examples
#' make_sensor_column_names(report$sensorList[[1]])
make_sensor_column_names <- function(sensorInfo)
{
    sensorInfo$columns %>% 
        unlist() %>% 
        tibble::enframe(name='index', value='id') %>% 
        dplyr::left_join(relate_sensor_id_to_name(sensorInfo$sensors), by=c('id'='ID')) %>% 
        dplyr::mutate(name=as.character(name)) %>% 
        dplyr::mutate(name=dplyr::if_else(is.na(name), id, name))
}


#' Title
#' @details Extracts all the readings from each set of physical sensors
#' @param sensor 
#' 
#' @return
#' @export
#'
#' @examples
#' extract_one_sensor_info(report$sensorList[[1]])
extract_one_sensor_info <- function(sensor)
{
    sensor_col_names <- make_sensor_column_names(sensor)$name
    sensor$data %>% 
        unlist() %>% 
        readr::read_csv(col_names=sensor_col_names) %>% 
        tidyr::pivot_longer(cols=c(-date, -time), names_to='Sensor', values_to='Reading') %>% 
        dplyr::slice(grep(pattern='_(temperature)|(occupancy)$', x=Sensor, ignore.case=FALSE)) %>% 
        tidyr::separate(col=Sensor, into=c('Sensor', 'Measure'), sep='_', remove=TRUE) %>% 
        dplyr::mutate(Sensor=sub(pattern='Thermostat .+$', replacement='Thermostat', x=Sensor)) %>% 
        tidyr::pivot_wider(names_from=Measure, values_from=Reading)
}


#' Title
#' @details Gets the readings for all the sensors for al lthe thermostats
#' @param report 
#'
#' @return
#' @export
#'
#' @examples
#' extract_sensor_info(report)
extract_sensor_info <- function(report)
{
    names(report$sensorList) <- purrr::map_chr(report$reportList, 'thermostatIdentifier')
    purrr::map_df(report$sensorList, extract_one_sensor_info, .id='Thermostat')
}


#' Title
#' @details Gets all the readings data from a central thermostat
#' @param thermostat 
#' @param colnames Comma-separated character of column names as specified in the Ecobee API
#'
#' @return
#' @export
#'
#' @examples
#' extract_one_thermostat_info(report$reportList[[1]], strsplit(x=report$columns, split=',')[[1]])
extract_one_thermostat_info <- function(thermostat, colnames)
{
    thermostat$rowList %>% 
        unlist() %>% 
        readr::read_csv(col_names=c('date', 'time', colnames))
}


#' Title
#' @details Gets all the readings data from multiple central thermostats
#' @param report 
#'
#' @return
#' @export
#'
#' @examples
#' extract_thermostat_info(report)
extract_thermostat_info <- function(report)
{
    names(report$reportList) <- purrr::map_chr(report$reportList, 'thermostatIdentifier')
    purrr::map_df(
        report$reportList, 
        extract_one_thermostat_info, colnames=strsplit(x=report$columns, split=',')[[1]], 
        .id='Thermostat'
    )
}

#' Title
#' @details Gets information about multiple thermostats
#' @param access_token 
#'
#' @return
#' @export
#'
#' @examples
#' get_thermostat_info(access_token)
get_thermostat_info <- function(access_token)
{
    httr::GET(
        'https://api.ecobee.com/1/thermostat?format=json&body={"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":false,"includeSettings":false,"includeSensors":false,"includeWeather":false,"includeLocation":true}}'
        , httr::add_headers(Authorization=glue::glue('Bearer {access_token}'))
        , encode='json'
    ) %>% 
        httr::content()
}

#' Title
#'
#' @param thermostat_info 
#'
#' @return Character of comma-separated thermostat IDs
#' @export
#'
#' @examples
get_thermostat_ids <- function(thermostat_info)
{
    thermostat_info$thermostatList %>% 
        purrr::map_chr('identifier') %>% 
        paste(collapse=',')
}


#' Title
#' @details Gets the user-created names of thermostats rather than their identifiers
#' @param thermostat_object 
#'
#' @return
#' @export
#'
#' @examples
#' thermo_info <- get_thermostat_info(access_token)
#' get_thermostat_names(thermo_info)
get_thermostat_names <- function(thermostat_object)
{
    tibble::tibble(
        ID=purrr::map_chr(thermostat_object$thermostatList, 'identifier')
        , Name=purrr::map_chr(thermostat_object$thermostatList, 'name')
    )
}

#' Title
#'
#' @param thermostat_level 
#' @param sensor_level 
#' @param thermostat_names 
#'
#' @return
#' @export
#'
#' @examples
#' access_token <- get_token(api_key=Sys.getenv('ECOBEE_API_KEY'), refresh_token=Sys.getenv('ECOBEE_REFRESH_TOKEN'))
#' get_report(startDate=start_date, endDate=end_date, thermostats=thermostats, access_token=access_token)
#' thermo_names <- get_thermostat_names(thermo_info)
#' central_info <- extract_thermostat_info(report)
#' ind_info <- extract_sensor_info(report)
#' all_info <- combine_thermostat_sensors(central_info, ind_info, thermo_names) 
combine_thermostat_sensors <- function(thermostat_level, sensor_level, thermostat_names)
{
    dplyr::inner_join(x=thermostat_level, y=sensor_level, by=c('Thermostat', 'date', 'time')) %>% 
        dplyr::left_join(thermostat_names, by=c('Thermostat'='ID')) %>% 
        dplyr::mutate(Sensor=dplyr::if_else(Sensor=='Thermostat', glue::glue('{Name} Thermostat'), Sensor)) %>% 
        dplyr::relocate(Name, Sensor, date, time, temperature, occupancy)
}

#' Title
#' @details Figuring out what UTC date to use to run the report. Assumes all thermostats are in the same place.
#' @param thermostat_info 
#'
#' @return
#' @export
#'
#' @examples
get_utc_date <- function(thermostat_info)
{
    as.character(as.Date(thermostat_info$thermostatList[[1]]$utcTime))
}

#' Title
#'
#' @param thermostat_info
#' @param override
#'
#' @return
#' @export
#'
#' @examples
#' the_info <- get_thermostat_info(access_token)
#' get_local_date(the_info)
get_local_date <- function(thermostat_info, override=NULL)
{
    if(!is.null(override))
    {
        return(override)
    }
    as.Date(thermostat_info$thermostatList[[1]]$thermostatTime)
}

#' Title
#'
#' @param thermostat_info 
#'
#' @return
#' @export
#'
#' @examples
#' the_info <- get_thermostat_info(access_token)
#' get_time_offset(the_info)
get_time_offset <- function(thermostat_info)
{
    thermostat_info$thermostatList[[1]]$location$timeZoneOffsetMinutes
}

#' Title
#'
#' @param thermostat_info
#' @param override
#'
#' @return
#' @export
#'
#' @examples
#' the_info <- get_thermostat_info(access_token)
#' compute_start_date(the_info)
compute_start_date <- function(thermostat_info, override=NULL)
{
    if(!is.null(override))
    {
        first_part <- override
    } else
    {
        first_part <- get_local_date(thermostat_info)
    }
    
    first_part + (get_time_offset(thermostat_info) > 0)
}

#' Title
#'
#' @param thermostat_info 
#' @param override
#'
#' @return
#' @export
#'
#' @examples
#' the_info <- get_thermostat_info(access_token)
#' compute_end_date(the_info)
compute_end_date <- function(thermostat_info, override=NULL)
{
    if(!is.null(override))
    {
        first_part <- override
    } else
    {
        first_part <- get_local_date(thermostat_info)
    }
    
    first_part + (get_time_offset(thermostat_info) < 0)
}

#' Title
#'
#' @param thermostat_info 
#'
#' @return
#' @export
#'
#' @examples
#' the_info <- get_thermostat_info(access_token)
#' compute_start_interval(the_info)
compute_start_interval <- function(thermostat_info)
{
    # intervals go from 0 to 287
    # if west of UTC we need to move minutes/5 forward
    # if east of UTC we need to move minutes/5 backward
    287*(get_time_offset(thermostat_info) > 0) - get_time_offset(thermostat_info)/5
}


#' Title
#'
#' @param thermostat_info 
#'
#' @return
#' @export
#'
#' @examples
#' the_info <- get_thermostat_info(access_token)
#' the_start <- compute_start_interval(the_info)
#' compute_end_interval(the_start)
compute_end_interval <- function(start_interval)
{
    # needs to end one interval before the start
    start_interval - 1
}

#' Title
#'
#' @param data 
#' @param file 
#'
#' @return
#' @export
#'
#' @examples
write_file <- function(data, file)
{
    readr::write_csv(x=data, file=file)
    return(file)
}
