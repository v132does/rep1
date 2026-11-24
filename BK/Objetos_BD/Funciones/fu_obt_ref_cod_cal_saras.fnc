CREATE OR REPLACE FUNCTION it.fu_obt_ref_cod_cal_saras (
   p_cod_rub_economico IN it.sb_crc_rub_economicos.cod_rub_economico%TYPE
) RETURN varchar2 IS
   v_cod_cal_saras it.sb_crc_rub_economicos.cod_cal_saras%TYPE;
BEGIN
   SELECT NVL(cod_cal_saras, 'Z')
   INTO v_cod_cal_saras
   FROM it.sb_crc_rub_economicos 
   WHERE cod_rub_economico = p_cod_rub_economico
   AND ROWNUM = 1;

   RETURN v_cod_cal_saras;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN 'Z';
   WHEN OTHERS THEN
      RETURN 'Z';
END;
/