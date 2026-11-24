CREATE OR REPLACE FUNCTION IT.fut_obt_cod_uuid(p_fecha TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP) RETURN RAW IS
/*generador de identificador UUID V7*/
    v_fec_actual  TIMESTAMP WITH TIME ZONE;
    v_unix        NUMBER;
    v_hex_fecha   VARCHAR2(12);
    v_ran_corto   VARCHAR2(3);
    v_ran_largo   VARCHAR2(16);
    v_uuid        VARCHAR2(32);
    v_constante    CONSTANT TIMESTAMP WITH TIME ZONE := TO_TIMESTAMP_TZ('1970-01-01 00:00:00 +00:00','YYYY-MM-DD HH24:MI:SS TZH:TZM');
BEGIN
    -- 0. Se recibe el parametro
    v_fec_actual := p_fecha;

    -- 1. Timestamp en ms
    v_unix := (EXTRACT(DAY FROM (v_fec_actual - v_constante)) * 86400000)
                  + (EXTRACT(HOUR FROM (v_fec_actual - v_constante)) * 3600000)
                  + (EXTRACT(MINUTE FROM (v_fec_actual - v_constante)) * 60000)
                  + FLOOR(EXTRACT(SECOND FROM (v_fec_actual - v_constante)) * 1000);

    -- 2. Formateo con FM para evitar espacios (Total 12 caracteres)
    v_hex_fecha := LPAD(LOWER(TO_CHAR(v_unix, 'FMxxxxxxxxxxxx')), 12, '0');

    -- 3. Random (C)orto (Total 3 caracteres)
    v_ran_corto := LPAD(LOWER(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(0, 4096)), 'FMxxx')), 3, '0');

    -- 4. Random (L)argo (Debe sumar 16 caracteres para que el total sea 32)
    -- Generamos 16 caracteres aleatorios limpios
    v_ran_largo := LPAD(LOWER(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(0, POWER(16, 16))), 'FMxxxxxxxxxxxxxxxx')), 16, '0');

    -- 5. Ensamblar: 12 (v_hex_fecha) + 1 (v7) + 3 (v_ran_corto) + 1 (var8) + 15 (v_ran_largo) = 32 chars
    v_uuid := v_hex_fecha || '7' || v_ran_corto || '8' || SUBSTR(v_ran_largo, 1, 15);

    RETURN HEXTORAW(v_uuid);
EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
END;
/
