CREATE OR REPLACE TRIGGER IT.TA_GE_TAS_RANGOS
   AFTER DELETE OR INSERT ON GE_TAS_RANGOS
DECLARE

/*Consultar si aún tiene registros en las tablas */
FUNCTION lf_obt_tasas RETURN NUMBER IS
   v_existe number;
BEGIN
   IF pag_gen.g_nro_cuenta is not null THEN
      SELECT count(1)
        INTO v_existe
        FROM ge_tas_fechas
       WHERE nro_cuenta = pag_gen.g_nro_cuenta;
      IF v_existe = 0 THEN
         SELECT count(1)
           INTO v_existe
           FROM ge_tas_rangos
          WHERE nro_cuenta = pag_gen.g_nro_cuenta;
      END IF;
   ELSIF pag_gen.g_cod_persona is not null THEN
      SELECT count(1)
        INTO v_existe
        FROM ge_tas_fechas
       WHERE cod_persona = pag_gen.g_cod_persona;
      IF v_existe = 0 THEN
         SELECT count(1)
           INTO v_existe
           FROM ge_tas_rangos
          WHERE cod_persona = pag_gen.g_cod_persona;
      END IF;
   END IF;
   RETURN v_existe;
END;
/* Actualizar cuenta ahorro o cuenta corriente según su tipo */
PROCEDURE lp_act_cuenta (ind in varchar2) IS
BEGIN
   IF pag_gen.g_tip_cuenta = 'CV' THEN
      UPDATE ah_cta_vistas
         SET tas_personalizada = ind
       WHERE nro_cuenta = pag_gen.g_nro_cuenta;
   ELSIF pag_gen.g_tip_cuenta = 'CC' THEN
      UPDATE cc_cta_corrientes
         SET tas_personalizada = ind
       WHERE nro_cuenta = pag_gen.g_nro_cuenta;
   END IF;
END;
/* Actualizar registro de la persona */
PROCEDURE lp_act_persona (ind in varchar2) IS
BEGIN
   UPDATE ba_personas
      SET tas_personalizada = ind
    WHERE cod_persona = pag_gen.g_cod_persona;
END;

BEGIN
   IF inserting THEN
      IF pag_gen.g_nro_cuenta is not null THEN
         lp_act_cuenta('S');
      ELSIF pag_gen.g_cod_persona is not null THEN
         lp_act_persona('S');
      END IF;
   ELSIF deleting THEN
      IF lf_obt_tasas = 0 THEN
         IF pag_gen.g_nro_cuenta is not null THEN
            lp_act_cuenta('N');
         ELSIF pag_gen.g_cod_persona is not null THEN
            lp_act_persona('N');
         END IF;
      END IF;   
   END IF;
END;
/

