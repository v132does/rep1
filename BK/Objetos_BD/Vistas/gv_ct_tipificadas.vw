CREATE OR REPLACE VIEW IT.GV_CTA_TIPIFICADAS AS
SELECT
    c.NRO_CUENTA,
    (SELECT 
        CASE 
            WHEN EXISTS (
                SELECT 1
                FROM GE_CTA_CLIENTES cl
                JOIN BA_PERSONAS P ON cl.COD_PERSONA = P.COD_PERSONA
                WHERE cl.NRO_CUENTA = c.NRO_CUENTA
                AND P.TIPO = 'J'
            ) THEN 'EMPRESA'
            ELSE 'INDIVIDUO'
        END
     FROM DUAL) AS NAT_LEGAL
FROM GE_CUENTAS c;
/
