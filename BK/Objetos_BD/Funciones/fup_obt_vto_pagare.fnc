CREATE OR REPLACE FUNCTION IT.fup_obt_vto_pagare(fec_vencimiento IN DATE,
                                              fec_inicio      IN DATE) RETURN VARCHAR2 AS
   años       NUMBER;
   meses      NUMBER;
   dias       NUMBER;
   v_años     VARCHAR2(15);
   v_meses    VARCHAR2(15);
   v_dias     VARCHAR2(15);
   v_completo VARCHAR2(40);
BEGIN
   SELECT FLOOR(months_between(fec_vencimiento, fec_inicio) / 12)
     INTO años
     FROM dual;
   SELECT FLOOR(MOD(months_between(fec_vencimiento, fec_inicio), 12))
     INTO meses
     FROM dual;
   SELECT FLOOR((MOD(months_between(fec_vencimiento, fec_inicio), 12) - FLOOR(MOD(months_between(fec_vencimiento, fec_inicio), 12))) * 30)
     INTO dias
     FROM dual;
   IF años = 0 THEN
      v_años := '';
   ELSIF años = 1 THEN
      v_años := años || ' año ';
   ELSE
      v_años := años || ' años ';
   END IF;
   IF meses = 0 THEN
      v_meses := '';
   ELSIF meses = 1 THEN
      v_meses := meses || ' mes ';
   ELSE
      v_meses := meses || ' meses ';
   END IF;
   IF Dias = 0 THEN
      v_dias := '';
   ELSIF Dias = 1 THEN
      v_dias := Dias + 1 || ' día ';
   ELSE
      v_dias := Dias + 1 || ' días ';
   END IF;
   v_completo := v_años || v_meses || v_dias;
   RETURN v_completo;
END fup_obt_vto_pagare;
/

