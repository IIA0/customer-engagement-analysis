USE 365_database;


-- RETRIEVING COURSES INFORMATION

 

-- Create a CTE (Common Table Expression) to calculate the total minutes watched and number of unique students per course
WITH title_total_minutes AS
(
SELECT 
    course_id, 
    course_title, 
    round(sum(minutes_watched), 2) as total_minutes_watched, 
    count(distinct student_id) as num_students
FROM
    365_course_info
        JOIN
    365_student_learning USING (course_id)
GROUP BY course_id
),

-- Create a second CTE to calculate the average minutes watched per student for each course
title_average_minutes AS
(
SELECT 
    m.course_id,
    m.course_title,
    m.total_minutes_watched,
    round(m.total_minutes_watched/m.num_students, 2) as average_minutes
    FROM
title_total_minutes m -- Referencing the first CTE here
),


-- Create a third CTE to add course ratings. For each course, calculate the total number of ratings and their average
title_ratings AS
(
SELECT 
    a.*,
    COUNT(course_rating) AS number_of_ratings,
    
    -- If there are no ratings, set average rating to 0
    IF(COUNT(course_rating) != 0, SUM(course_rating) / COUNT(course_rating), 0) AS average_rating
FROM
    title_average_minutes a -- Referencing the second CTE here
        LEFT JOIN
    365_course_ratings r USING (course_id)
GROUP BY course_id
)

-- Finally, select all fields from the last CTE to get the desired result set
SELECT 
    *
FROM
    title_ratings;
    
    
    
-- RETRIEVING PURCHASE INFORMATION
    
   


DROP VIEW IF EXISTS purchases_info;


CREATE VIEW purchases_info AS
    SELECT 
        purchase_id,
        student_id,
        purchase_type,
        date_purchased AS date_start, -- Rename 'date_purchased' to 'date_start' for clarity
        CASE
			-- Determine the 'date_end' based on 'purchase_type' 
            -- If the purchase type is 'Monthly', add one month to 'date_purchased' to get 'date_end'
            WHEN
                purchase_type = 'Monthly'
            THEN
                DATE_ADD(MAKEDATE(YEAR(date_purchased),
                            DAY(date_purchased)),
                    INTERVAL MONTH(date_purchased) MONTH)
                    
			-- If the purchase type is 'Quarterly', add three months to 'date_purchased' to get 'date_end'
            WHEN
                purchase_type = 'Quarterly'
            THEN
                DATE_ADD(MAKEDATE(YEAR(date_purchased),
                            DAY(date_purchased)),
                    INTERVAL MONTH(date_purchased) + 2 MONTH)
                    
			-- If the purchase type is 'Annual', add twelve months to 'date_purchased' to get 'date_end'
            WHEN
                purchase_type = 'Annual'
            THEN
                DATE_ADD(MAKEDATE(YEAR(date_purchased),
                            DAY(date_purchased)),
                    INTERVAL MONTH(date_purchased) + 11 MONTH)
        END AS date_end
    FROM
        365_student_purchases;
        
        
    
 -- RETRIEVING STUDENTS INFORMATION
        
        

SELECT 
    student_id,
    student_country,
    date_registered,
    date_watched,
    minutes_watched,
    onboarded,
    -- Determine if the student had a paid membership on a specific date
    MAX(paid) AS paid
FROM
    ( -- Sub-query to check if the date the student watched falls between the payment start and end dates
    SELECT 
        a.*,
		IF(date_watched BETWEEN p.date_start AND p.date_end, 1, 0) AS paid
    FROM
        ( -- Sub-query to aggregate the minutes watched by student and date_watched; Determine if a student has onboarded or not
        SELECT 
        i.*,
            l.date_watched,
            
            -- If no watch date, set minutes to 0, else sum the minutes watched and round to two decimal places
            IF(l.student_id IS NULL, 0, ROUND(SUM(l.minutes_watched), 2)) AS minutes_watched,
            
            -- Determine if the student has onboarded (1 for onboarded, 0 for not onboarded)
            IF(l.student_id IS NULL, 0, 1) AS onboarded
    FROM
        365_student_info i
	-- Left join on student learning data to include all students, even if they didn't have learning data
    LEFT JOIN 365_student_learning l USING (student_id)
    GROUP BY student_id , date_watched) a
    
    -- Left join with purchases_info to associate payment details with students
    LEFT JOIN purchases_info p USING (student_id)) b
    
-- Group results by individual student and the date they watched content
GROUP BY student_id , date_watched;