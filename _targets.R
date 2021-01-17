# packages needed for targets
library(targets)
library(tarchetypes)

# this has helper functions
source("R/utilities.r")
# functions for the actual workflow
source("R/functions.r")

options(tidyverse.quiet = TRUE)
# magrittr will be available for every step
tar_option_set(packages = c("magrittr"))

# If the token is older than this long refresh it
token_lifespan <- as.difftime(60, units='mins')
token_target_path <- tar_path(access_token)

bucket_name <- Sys.getenv('BUCKET_NAME')
folder_name <- Sys.getenv('FOLDER_NAME')

if(!exists('process_date'))
{
    process_date <- NULL
}
cat(process_date)


# if we want to hardcode a data, but there has to be a better way
# start_now <- as.Date('2021-01-03')

list(
    tar_force(
        access_token,
        get_token(api_key=Sys.getenv('ECOBEE_API_KEY'), refresh_token=Sys.getenv('ECOBEE_REFRESH_TOKEN')),
        # if the token is too old or doesn't exist, run
        if_not_na(Sys.time() - file.mtime(token_target_path), token_lifespan) >= token_lifespan
    )
    , tar_target(
        thermostat_info,
        get_thermostat_info(access_token)
    )
    , tar_target(
        thermostat_ids,
        get_thermostat_ids(thermostat_info)
    )
    , tar_target(
        start_date,
        # if we want to hardcode a data, but there has to be a better way
        # start_now
        compute_start_date(thermostat_info, override=process_date)
    )
    , tar_target(
        end_date,
        # if we want to hardcode a data, but there has to be a better way
        # start_now + 1
        compute_end_date(thermostat_info, override=process_date)
    )
    , tar_target(
        start_interval,
        compute_start_interval(thermostat_info)
    )
    , tar_target(
        end_interval,
        compute_end_interval(start_interval)
    )
    , tar_target(
        report,
        get_report(
            startDate=start_date, endDate=end_date,
            startInterval=start_interval, endInterval=end_interval,
            thermostats=thermostat_ids, 
            access_token=access_token
        )
    )
    , tar_target(
        thermostat_names,
        get_thermostat_names(thermostat_info)
    )
    , tar_target(
        central_thermostat_info, 
        extract_thermostat_info(report)
    )
    , tar_target(
        sensor_info,
        extract_sensor_info(report)
    )
    , tar_target(
        all_info,
        combine_thermostat_sensors(central_thermostat_info, sensor_info, thermostat_names) 
    )
    , tar_target(
        data_date,
        # if we want to hardcode a data, but there has to be a better way
        # start_now
        get_local_date(thermostat_info, override=process_date)
    )
    , tar_target(
        filename,
        paste(data_date, 'csv', sep='.')
    )
    , tar_target(
        filepath,
        # tempfile(fileext='.csv')
        here::here('data', filename)
    )
    , tar_target(
        write_data,
        write_file(all_info, file=filename),
        format='file'
    )
    , tar_target(
        put_to_bucket,
        aws.s3::put_object(
            file=write_data, object=sprintf('%s/%s', folder_name, filename), bucket=bucket_name
        )
    )
    , tar_target(
        delete_file,
        if(file.exists(filename)) unlink(filename)
    )
)
