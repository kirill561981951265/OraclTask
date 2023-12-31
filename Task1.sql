

CREATE TABLE article (
    id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    crt_dt DATE DEFAULT SYSDATE NOT NULL,
    mod_dt DATE DEFAULT SYSDATE NOT NULL,
    author VARCHAR2(128) NOT NULL,
    title VARCHAR2(50) NOT NULL,
    content CLOB NOT NULL
);

CREATE TABLE article_comment (
    id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    article_id INT NOT NULL,
    ts TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP NOT NULL,
    reply_to_id INT,
    rating INT,
    votes INT,
    commenter VARCHAR2(128) NOT NULL,
    content CLOB NOT NULL
)
PARTITION BY RANGE (ts)
(
    PARTITION p_prev_year VALUES LESS THAN (TIMESTAMP '2022-01-01 00:00:00'),
    PARTITION p_current_year VALUES LESS THAN (TIMESTAMP '2023-01-01 00:00:00'),
    PARTITION p_next_year VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00')
);

CREATE TABLE audit_action (
    id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ts TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP NOT NULL,
    table_name VARCHAR2(128) NOT NULL,
    row_id INT NOT NULL,
    user_name VARCHAR2(128) NOT NULL,
    action_type CHAR(1) CHECK (action_type IN ('I', 'U', 'D')),
    action_summary VARCHAR2(250) NOT NULL
);

drop table ARTICLE_COMMENT;
------------------------------trigger

CREATE OR REPLACE TRIGGER before_insert_update_trigger
BEFORE INSERT OR UPDATE ON article
FOR EACH ROW
DECLARE
BEGIN
    -- Check that author is not empty
    IF :NEW.author IS NULL THEN
        RAISE_APPLICATION_ERROR(-20101, 'Error: Author of the article cannot be empty.');
    END IF;

    -- Check that title is not empty and is not in UPPER CASE
     IF NVL(:NEW.title, ' ') = ' ' OR :NEW.title != UPPER(:NEW.title) THEN
        RAISE_APPLICATION_ERROR(-20103, 'Error: Title of the article cannot be empty or in UPPER CASE.');
    END IF;

    -- Check that content is not empty
    IF NVL(:NEW.content, ' ') = ' ' THEN
        RAISE_APPLICATION_ERROR(-20104, 'Error: Content of the article cannot be empty.');
    END IF;
END;

CREATE OR REPLACE TRIGGER trg_audit_article
BEFORE INSERT OR UPDATE OR DELETE ON article
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article', :NEW.id, USER, 'I', 'New row inserted');
    ELSIF UPDATING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article', :NEW.id, USER, 'U', 'Row updated');
    ELSIF DELETING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article', :OLD.id, USER, 'D', 'Row deleted');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_audit_article_comment
BEFORE INSERT OR UPDATE OR DELETE ON article_comment
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article_comment', :NEW.id, USER, 'I', 'New row inserted');
    ELSIF UPDATING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article_comment', :NEW.id, USER, 'U', 'Row updated');
    ELSIF DELETING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article_comment', :OLD.id, USER, 'D', 'Row deleted');
    END IF;
END;
/


INSERT INTO article (author, title, content)
VALUES ('', 'Заголовок1', 'Содержание1');

INSERT INTO article (author, title, content)
VALUES ('Автор2', 'ф', 'Содержание2');

INSERT INTO article (author, title, content)
VALUES ('Автор3', 'Заголовок3', '');

CREATE OR REPLACE VIEW article_comment_v AS
SELECT
    ac.id,
    ac.article_id,
    a.author AS article_author,
    a.title AS article_title,
    ac.ts,
    ac.rating,
    ac.commenter,
    ac.content,
    SUBSTR(ac_in_reply_to.content, 1, 50) AS in_reply_to
FROM
    article_comment ac
JOIN
    article a ON ac.article_id = a.id
LEFT JOIN
    article_comment ac_in_reply_to ON ac.reply_to_id = ac_in_reply_to.id;




SELECT * FROM ARTICLE_COMMENT PARTITION (p_next_year);
select * from ARTICLE;
select * from ARTICLE_COMMENT;
delete from ARTICLE;
commit ;
-- Комментарий 1 к статье 1
INSERT INTO article (author, title, content)
VALUES ('A', 'A', 'A');

INSERT INTO article (crt_dt, mod_dt, author, title, content)
VALUES (SYSDATE, SYSDATE, 'John Doe', ' SQL', 'This is an introductory article about SQL.');

INSERT INTO article (crt_dt, mod_dt, author, title, content)
VALUES (SYSDATE, SYSDATE, 'Jane Smith', 'DATA', 'Exploring the fundamentals of data modeling.');

INSERT INTO article (crt_dt, mod_dt, author, title, content)
VALUES (SYSDATE, SYSDATE, 'Bob Johnson', 'ADVANCED', 'A deep dive into advanced SQL concepts and techniques.');

INSERT INTO article_comment (article_id, ts, reply_to_id, rating, votes, commenter, content)
VALUES (1, TIMESTAMP '2022-01-15 12:30:00', NULL, 5, 10, 'User1', 'Комментарий 1');

-- Комментарий 2 к статье 1
INSERT INTO article_comment (article_id, ts, reply_to_id, rating, votes, commenter, content)
VALUES (1, TIMESTAMP '2023-02-20 14:45:00', NULL, 3, 8, 'User2', 'Комментарий 2');

-- Комментарий 3 к статье 2
INSERT INTO article_comment (article_id, ts, reply_to_id, rating, votes, commenter, content)
VALUES (2, TIMESTAMP '2023-04-05 18:00:00', NULL, 2, 5, 'User4', 'Комментарий 3');

-- Пакет tapi_comment
-- Спецификация пакета
CREATE OR REPLACE PACKAGE tapi_comment AS
    PROCEDURE tapi_comment_create(i_id IN NUMBER, i_article_id IN NUMBER, i_commenter IN VARCHAR2, i_content IN CLOB);
    PROCEDURE tapi_comment_change(i_id IN NUMBER, i_article_id IN NUMBER, i_commenter IN VARCHAR2, i_content IN CLOB);
    PROCEDURE tapi_comment_add_like(i_id IN NUMBER);
    PROCEDURE tapi_comment_add_dislike(i_id IN NUMBER);
END tapi_comment;

-- Тело пакета
CREATE OR REPLACE PACKAGE BODY tapi_comment AS
    PROCEDURE tapi_comment_save (
        p_id IN NUMBER,
        p_article_id IN INT,
        p_reply_to_id IN INT,
        p_rating IN INT,
        p_votes IN INT,
        p_commenter IN VARCHAR2,
        p_content IN CLOB
    )
    IS
    BEGIN
        MERGE INTO article_comment ac
        USING DUAl
        ON (ac.id = p_id)
        WHEN MATCHED THEN
            UPDATE SET
                ac.article_id = p_article_id,
                ac.reply_to_id = p_reply_to_id,
                ac.rating = p_rating,
                ac.votes = p_votes,
                ac.commenter = p_commenter,
                ac.content = p_content
        WHEN NOT MATCHED THEN
            INSERT (
                id,
                article_id,
                reply_to_id,
                rating,
                votes,
                commenter,
                content
            )
            VALUES (
                p_id,
                p_article_id,
                p_reply_to_id,
                p_rating,
                p_votes,
                p_commenter,
                p_content
            );
    END;

    PROCEDURE tapi_comment_create(i_id IN NUMBER, i_article_id IN NUMBER, i_commenter IN VARCHAR2, i_content IN CLOB) IS
    BEGIN
        tapi_comment_save(i_id, i_article_id, null, null, null, i_commenter, i_content);
    END tapi_comment_create;

    PROCEDURE tapi_comment_change(i_id IN NUMBER, i_article_id IN NUMBER, i_commenter IN VARCHAR2, i_content IN CLOB) IS
    BEGIN
        tapi_comment_save(i_id, i_article_id, null, null, null, i_commenter, i_content);
    END tapi_comment_change;

     PROCEDURE tapi_change_votes(i_ac_id IN NUMBER) IS
    BEGIN
        -- Увеличить количество голосов у комментария
        UPDATE article_comment
        SET votes = votes + 1
        WHERE id = i_ac_id;
    END tapi_change_votes;

    -- Реализация процедуры tapi_change_rating
    PROCEDURE tapi_change_rating(i_ac_id IN NUMBER,i_votes IN NUMBER DEFAULT 1) IS
    BEGIN
        -- Увеличить рейтинг у комментария (add_like) или уменьшить (add_dislike)
        UPDATE article_comment
        SET rating = rating + i_votes
        WHERE id = i_ac_id;
    END tapi_change_rating;

   PROCEDURE tapi_comment_add_like(i_id IN NUMBER) IS
    BEGIN
        -- Реализация метода tapi_comment_add_like
        tapi_change_votes(i_id);
        tapi_change_rating(i_id,1);
    END tapi_comment_add_like;

    PROCEDURE tapi_comment_add_dislike(i_id IN NUMBER) IS
    BEGIN
        -- Реализация метода tapi_comment_add_dislike
        tapi_change_votes(i_id);
        tapi_change_rating(i_id,-1);
    END tapi_comment_add_dislike;
END tapi_comment;



BEGIN
    TAPI_COMMENT.tapi_comment_create(
        i_id => 41,
        i_article_id => 20,
        i_commenter => 'User2',
        i_content => 'Комментарий 2'
    );
END;


-- Вызов метода tapi_comment_change
BEGIN
    tapi_comment.tapi_comment_change(
        i_id =>39,
        i_article_id => 20,
        i_commenter => 'User3',
        i_content => 'Измененный комментарий 3'
    );
END;

-- Вызов метода tapi_comment_add_like
BEGIN
    tapi_comment.TAPI_COMMENT_ADD_LIKE(
        i_id => 37
    );
END;

-- Вызов метода tapi_comment_add_dislike
BEGIN
    tapi_comment.tapi_comment_add_dislike(
        i_id => 37
    );
END;
/

CREATE CONTEXT TAPI_AUDIT_CTX USING tapi_audit;
----audit package
CREATE OR REPLACE PACKAGE tapi_audit IS

  PROCEDURE tapi_audit_specify_secret_key(i_key IN VARCHAR2);
  PROCEDURE tapi_audit_disable(i_table_name IN VARCHAR2);
    PROCEDURE tapi_audit_enable(i_table_name IN VARCHAR2);
END tapi_audit;

    CREATE OR REPLACE PACKAGE BODY tapi_audit IS
    SECRET_KEY CONSTANT VARCHAR2(100) := 'your_secret_key';
  PROCEDURE tapi_audit_specify_secret_key(i_key IN VARCHAR2) IS
  BEGIN
    DBMS_SESSION.SET_CONTEXT('TAPI_AUDIT_CTX', 'SECRET_KEY', i_key);
  END tapi_audit_specify_secret_key;


  PROCEDURE tapi_audit_activate_trigger(i_table_name IN VARCHAR2, i_enable IN BOOLEAN) IS
   BEGIN
 DBMS_OUTPUT.PUT_LINE('1');
        IF SYS_CONTEXT('TAPI_AUDIT_CTX', 'SECRET_KEY') = SECRET_KEY THEN
 DBMS_OUTPUT.PUT_LINE('2');
            IF i_enable THEN
                       FOR trg IN (SELECT trigger_name FROM all_triggers WHERE table_name = i_table_name) LOOP
    EXECUTE IMMEDIATE 'ALTER TRIGGER ' || trg.trigger_name || ' ENABLE';
  END LOOP;
            ELSE
                 DBMS_OUTPUT.PUT_LINE('3');
               FOR trg IN (SELECT trigger_name FROM all_triggers WHERE table_name = i_table_name) LOOP
    EXECUTE IMMEDIATE 'ALTER TRIGGER ' || trg.trigger_name || ' DISABLE';
  END LOOP;
            END IF;
        ELSE
            -- Если ключ не соответствует, вызвать ошибку
            RAISE_APPLICATION_ERROR(-20001, 'Invalid secret key');
        END IF;
    END tapi_audit_activate_trigger;

  -- Procedure to enable auditing for a table
  PROCEDURE tapi_audit_enable(i_table_name IN VARCHAR2) IS
    l_dummy NUMBER;
  BEGIN
    SELECT 1 INTO l_dummy FROM user_tables WHERE table_name = i_table_name;
   tapi_audit_activate_trigger(i_table_name,TRUE);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20203, 'Table does not exist');
  END tapi_audit_enable;

  -- Procedure to disable auditing for a table
  PROCEDURE tapi_audit_disable(i_table_name IN VARCHAR2) IS
    l_dummy NUMBER;
  BEGIN
    SELECT 1 INTO l_dummy FROM user_tables WHERE table_name = i_table_name;
   tapi_audit_activate_trigger(i_table_name,false);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20203, 'Table does not exist');
  END tapi_audit_disable;
END tapi_audit;



        -- Test for specifying secret key
BEGIN
    tapi_audit.tapi_audit_specify_secret_key('your_secret_key');
    DBMS_OUTPUT.PUT_LINE('Secret key specified successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error specifying secret key: ' || SQLERRM);
END;

-- Test for enabling auditing for a table
BEGIN
    tapi_audit.tapi_audit_enable('ARTICLE');
    DBMS_OUTPUT.PUT_LINE('Auditing enabled successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error enabling auditing: ' || SQLERRM);
END;

BEGIN
    tapi_audit.tapi_audit_disable('ARTICLE');
    DBMS_OUTPUT.PUT_LINE('Auditing disabled successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error disabling auditing: ' || SQLERRM);
END;


INSERT INTO article (crt_dt, mod_dt, author, title, content)
VALUES (SYSDATE, SYSDATE, '', ' SQL', 'This is an introductory article about SQL.');

ALTER TABLE ARTICLE ENABLE ALL TRIGGERS;


  create or REPLACE PROCEDURE tapi_audit_specify_secret_key(i_key IN VARCHAR2) IS
  BEGIN
    DBMS_SESSION.SET_CONTEXT('TAPI_AUDIT_CTX', 'SECRET_KEY', 'your_secret_key');
  END;
DECLARE
  v_key VARCHAR2(100) := 'your_secret_key';
BEGIN
  tapi_audit_specify_secret_key(v_key);
END;

begin
   FOR trg IN (SELECT trigger_name FROM all_triggers WHERE table_name = 'ARTICLE') LOOP
    EXECUTE IMMEDIATE 'ALTER TRIGGER ' || trg.trigger_name || ' DISABLE';
  END LOOP;
end;

--users

CREATE USER c##blog_base IDENTIFIED BY blog_base;
CREATE USER c##blog_app IDENTIFIED BY blog_app;
CREATE USER c##blog_admin IDENTIFIED BY blog_admin;

GRANT CONNECT, RESOURCE TO c##blog_base;
GRANT CONNECT, RESOURCE TO c##blog_app;
GRANT CONNECT, RESOURCE TO c##blog_admin;

GRANT SELECT, INSERT, UPDATE, DELETE ON article TO c##blog_app;
GRANT SELECT ON article_comment_v TO c##blog_app;
GRANT EXECUTE ON tapi_comment TO c##blog_app;
GRANT EXECUTE ON tapi_audit TO c##blog_admin;

-- Создание схемы DWH
select * from AUDIT_ACTION;

CREATE OR REPLACE TRIGGER trg_audit_article
BEFORE INSERT OR UPDATE OR DELETE ON article
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article', :NEW.id, USER, 'I', 'New row inserted');
    ELSIF UPDATING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article', :NEW.id, USER, 'U', 'Row updated');
    ELSIF DELETING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article', :OLD.id, USER, 'D', 'Row deleted');
    END IF;
END;


CREATE OR REPLACE TRIGGER trg_audit_article_comment
BEFORE INSERT OR UPDATE OR DELETE ON article_comment
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article_comment', :NEW.id, USER, 'I', 'New row inserted');
    ELSIF UPDATING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article_comment', :NEW.id, USER, 'U', 'Row updated');
    ELSIF DELETING THEN
        INSERT INTO audit_action (table_name, row_id, user_name, action_type, action_summary)
        VALUES ('article_comment', :OLD.id, USER, 'D', 'Row deleted');
    END IF;
END;



CREATE TABLE article (
    id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    crt_dt DATE DEFAULT SYSDATE NOT NULL,
    mod_dt DATE DEFAULT SYSDATE NOT NULL,
    author VARCHAR2(128) NOT NULL,
    title VARCHAR2(50) NOT NULL,
    content CLOB NOT NULL
);

CREATE TABLE article_comment (
    id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    article_id INT NOT NULL,
    ts TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP NOT NULL,
    reply_to_id INT,
    rating INT,
    votes INT,
    commenter VARCHAR2(128) NOT NULL,
    content CLOB NOT NULL
)
PARTITION BY RANGE (ts)
(
    PARTITION p_prev_year VALUES LESS THAN (TIMESTAMP '2022-01-01 00:00:00'),
    PARTITION p_current_year VALUES LESS THAN (TIMESTAMP '2023-01-01 00:00:00'),
    PARTITION p_next_year VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00')
);
-- Создание таблицы dim_article
CREATE TABLE dim_article (
    sid INT GENERATED ALWAYS AS IDENTITY,
    nid INT NOT NULL,
    crt_dt DATE NOT NULL,
    mod_dt DATE NOT NULL,
    author VARCHAR2(128) NOT NULL,
    title VARCHAR2(50) NOT NULL,
    content CLOB NOT NULL,
    start_dt DATE DEFAULT CURRENT_TIMESTAMP,
    end_dt DATE DEFAULT NULL,
    is_act_ind NUMBER(1) DEFAULT 1,
    CONSTRAINT pk_dim_article PRIMARY KEY (sid)
);

CREATE TABLE dim_dates (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    d_date DATE NOT NULL,
    d_year INT NOT NULL,
    half_year INT NOT NULL,
    d_quarter INT NOT NULL,
    d_month INT NOT NULL,
    name_month VARCHAR2(20) NOT NULL ,
    d_day INT NOT NULL,
    d_week INT NOT NULL,
    begin_of_month INT NOT NULL,
    end_of_month INT NOT NULL
);
drop table f_article_comment;
drop table dim_dates;
-- Создание таблицы f_article_comment
CREATE TABLE f_article_comment (
    sid INT GENERATED ALWAYS AS IDENTITY,
    article_sid INT NOT NULL,
    date_id INT NOT NULL,
    comment_id INT NOT NULL,
    time_ival DATE NOT NULL,
    rating INT,
    votes INT,
    content CLOB NOT NULL,
    action_type CHAR(1) NOT NULL,
    CONSTRAINT pk_f_article_comment PRIMARY KEY (sid),
    CONSTRAINT fk_f_article_comment_article_sid FOREIGN KEY (article_sid) REFERENCES dim_article (sid),
    CONSTRAINT fk_f_article_comment_date_id FOREIGN KEY (date_id) REFERENCES dim_dates (id)
);



CREATE OR REPLACE PACKAGE etl_blog IS
  PROCEDURE etl_load_articles;
  PROCEDURE etl_load_comments;
END etl_blog;
/

CREATE OR REPLACE PACKAGE BODY etl_blog IS
  PROCEDURE etl_load_articles IS
  BEGIN

    DECLARE
  v_current_date DATE := SYSDATE;
BEGIN

  UPDATE dim_article
  SET end_dt = v_current_date,
      is_act_ind = 0
  WHERE nid IN (
    SELECT a.nid
    FROM dim_article a
    INNER JOIN article b ON a.nid = b.id
    WHERE a.is_act_ind = 1
      AND (a.author <> b.author OR a.title <> b.title)
  );

  -- Insert new records
  INSERT INTO dim_article (nid, crt_dt, mod_dt, author, title, content, start_dt, end_dt, is_act_ind)
  SELECT b.id, v_current_date, v_current_date, b.author, b.title, b.content, v_current_date, NULL, 1
  FROM article b
  LEFT JOIN dim_article a ON b.id = a.nid
  WHERE a.sid IS NULL;

  COMMIT;
END;
  END etl_load_articles;

  PROCEDURE etl_load_comments IS
BEGIN
    MERGE INTO f_article_comment f
    USING (
        SELECT
            c.id AS comment_sid,
            a.sid AS article_sid,
            d.id AS date_id,
            c.rating,
            c.votes,
            c.content,
            au.ts
        FROM article_comment c
        JOIN dim_article a ON c.article_id = a.nid
        JOIN dim_dates d ON TRUNC(c.ts) = d.d_date
        join audit_action au on c.ID=au.ROW_ID and au.TABLE_NAME='article_comment'
    ) s
    ON (f.comment_id = s.comment_sid AND f.article_sid = s.article_sid)
    WHEN MATCHED THEN
        UPDATE SET
            f.rating = s.rating,
            f.votes = s.votes,
            f.content = s.content,
            f.action_type = 'U'
    WHEN NOT MATCHED THEN
        INSERT (article_sid, date_id, comment_id, time_ival, rating, votes, content, action_type)
        VALUES (s.article_sid, s.date_id, s.comment_sid,s.ts, s.rating, s.votes, s.content, 'I');
END etl_load_comments;

END etl_blog;


DECLARE
    start_date DATE := TO_DATE('2024-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS');
    end_date DATE := TO_DATE('2024-12-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS');
    curate DATE := start_date;
BEGIN
    WHILE curate <= end_date LOOP
        DBMS_OUTPUT.PUT_LINE(curate);
        INSERT INTO dim_dates (
            d_date,
            d_year,
            half_year,
            d_quarter,
            d_month,
            name_month,
            d_day,
            d_week,
            begin_of_month,
            end_of_month
        ) VALUES (
            curate,
            EXTRACT(YEAR FROM curate),
            CASE WHEN EXTRACT(MONTH FROM curate) <= 6 THEN 1 ELSE 2 END,
            TO_NUMBER(TO_CHAR(curate, 'Q')),
            EXTRACT(MONTH FROM curate),
            TO_CHAR(curate, 'Month'),
            EXTRACT(DAY FROM curate),
            TO_NUMBER(TO_CHAR(curate, 'IW')),
            1,
            TO_NUMBER(TO_CHAR(LAST_DAY(curate), 'DD'))
        );
        curate := curate + INTERVAL '1' DAY; -- Увеличение даты на 1 день
    END LOOP;
    COMMIT;
END;

  BEGIN

    DBMS_SCHEDULER.CREATE_JOB (
      job_name => 'ETL_LOAD_ARTICLES_JOB',
      job_type => 'PLSQL_BLOCK',
      job_action => 'BEGIN etl_blog.etl_load_articles; END;',
      start_date => SYSTIMESTAMP,
      repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0;',
      enabled => TRUE
    );
end;
  BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
      job_name => 'ETL_LOAD_COMMENTS_JOB',
      job_type => 'PLSQL_BLOCK',
      job_action => 'BEGIN etl_blog.etl_load_comments; END;',
      start_date => SYSTIMESTAMP,
      repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=5; BYSECOND=0;',
      enabled => TRUE
    );
end;

---analytic



INSERT INTO article (crt_dt, mod_dt, author, title, content)
VALUES (SYSDATE, SYSDATE, 'Bob Johnson', 'ADVANCED', 'A deep dive into advanced SQL concepts and techniques.');
update article set AUTHOR='Bob' where ID=42;


delete from dim_dates;

SELECT
  TO_CHAR(start_dt, 'DAY') AS day_of_week,
  COUNT(*) AS number_of_articles
FROM
  dim_article
GROUP BY
  TO_CHAR(start_dt, 'DAY')
ORDER BY
  MIN(start_dt);

select * from dim_dates;
select * from f_article_comment;
select * from dim_article;
select * from article;
select * from audit_action;
BEGIN etl_blog.etl_load_comments; END;
INSERT INTO article_comment (article_id, ts, reply_to_id, rating, votes, commenter, content)
VALUES (1, TIMESTAMP '2023-02-20 14:45:00', NULL, 3, 8, 'User2', 'Комментарий 8');


SELECT
  TO_CHAR(TRUNC(time_ival, 'HH24'), 'HH24') || ':00:00 ... ' ||
  TO_CHAR(TRUNC(time_ival, 'HH24') + INTERVAL '59' MINUTE + INTERVAL '59' SECOND, 'HH24:MI:SS') AS time_interval,
  COUNT(*) AS comment_count,
  AVG(COUNT(*)) OVER (
    ORDER BY TRUNC(time_ival, 'HH24')
    RANGE BETWEEN INTERVAL '1' HOUR PRECEDING AND INTERVAL '1' HOUR FOLLOWING
  ) AS average_comments
FROM
  f_article_comment
GROUP BY
  TRUNC(time_ival, 'HH24')
ORDER BY
  TRUNC(time_ival, 'HH24');


--package
CREATE OR REPLACE PACKAGE stats IS
    TYPE rep1_record IS RECORD (
    week_day VARCHAR2(20),
    num_of_articles NUMBER
  );
         TYPE rep1_table IS TABLE OF rep1_record;
         TYPE rep2_record IS RECORD (
    hour_period VARCHAR2(250),
    exact_num_of_comments NUMBER,
    rolling_num_of_comments NUMBER
  );

  TYPE rep2_table IS TABLE OF rep2_record;

  FUNCTION report_articles(
    begin_date IN DATE,
    end_date IN DATE
  )  RETURN rep1_table PIPELINED;


  FUNCTION report_comments(
    begin_date IN DATE,
    end_date IN DATE
  )  RETURN rep2_table PIPELINED;
END stats;

CREATE OR REPLACE PACKAGE BODY stats IS
  FUNCTION report_articles(
  begin_date IN DATE,
  end_date IN DATE
) RETURN rep1_table PIPELINED IS
  -- Определите переменные и курсоры по мере необходимости
  v_week_day VARCHAR2(20);
  v_num_of_articles NUMBER;
BEGIN

  FOR i IN (
    SELECT
      TO_CHAR(start_dt, 'DAY') AS week_day,
      COUNT(*) AS num_of_articles
    FROM
      dim_article
    WHERE
      start_dt BETWEEN begin_date AND end_date
    GROUP BY
      TO_CHAR(start_dt, 'DAY')
    ORDER BY
      MIN(start_dt)
  ) LOOP
    v_week_day := i.week_day;
    v_num_of_articles := i.num_of_articles;
    PIPE ROW (rep1_record(v_week_day, v_num_of_articles));
  END LOOP;

  RETURN;
END report_articles;
  FUNCTION report_comments(
    begin_date IN DATE,
    end_date IN DATE
  )  RETURN rep2_table PIPELINED IS
  -- Определите переменные и курсоры по мере необходимости
  v_time_interval VARCHAR2(250);
  v_comment_count NUMBER;
  v_average_comments NUMBER;
BEGIN
  -- Query and calculations for report #2
  FOR i IN (
    SELECT
      TO_CHAR(TRUNC(time_ival, 'HH24'), 'HH24') || ':00:00 ... ' ||
      TO_CHAR(TRUNC(time_ival, 'HH24') + INTERVAL '59' MINUTE + INTERVAL '59' SECOND, 'HH24:MI:SS') AS time_interval,
      COUNT(*) AS comment_count,
      AVG(COUNT(*)) OVER (
        ORDER BY TRUNC(time_ival, 'HH24')
        RANGE BETWEEN INTERVAL '1' HOUR PRECEDING AND INTERVAL '1' HOUR FOLLOWING
      ) AS average_comments
    FROM
      f_article_comment
    WHERE
      time_ival BETWEEN begin_date AND end_date
    GROUP BY
      TRUNC(time_ival, 'HH24')
    ORDER BY
      TRUNC(time_ival, 'HH24')
  ) LOOP
    v_time_interval := i.time_interval;
    v_comment_count := i.comment_count;
    v_average_comments := i.average_comments;
    PIPE ROW (rep2_record(v_time_interval, v_comment_count, v_average_comments));
  END LOOP;

  RETURN;
END report_comments;

END stats;


SELECT rep1.week_day, rep1.num_of_articles
FROM TABLE(stats.report_articles(DATE '2023-01-01', DATE '2023-12-31')) rep1;

select rep2.hour_period
     , rep2.exact_num_of_comments
     , rep2.rolling_num_of_comments
from table( stats.report_comments (DATE '2023-01-01', DATE '2023-12-31')) rep2