CREATE OR REPLACE TRIGGER IT.TB_GE_PAR_CAUSALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_PAR_CAUSALES
 FOR EACH ROW


DECLARE

/* Obtener tipo de causa de la tabla ge_causales. */
FUNCTION LF_OBT_TIP_CAUSA
 (P_COD_CAUSA IN GE_CAUSALES.COD_CAUSA%TYPE
 )
 RETURN VARCHAR2;
   v_gparam    ge_parametros%rowtype;
   v_tipo      ge_causales.tipo%type;

/* Obtener tipo de causa de la tabla ge_causales. */
FUNCTION LF_OBT_TIP_CAUSA
 (P_COD_CAUSA IN GE_CAUSALES.COD_CAUSA%TYPE
 )
 RETURN VARCHAR2
 IS
v_tipo ge_causales.tipo%type;
BEGIN
   select tipo
   into v_tipo
   from ge_causales
   where cod_causa = p_cod_causa;
   return v_tipo;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Causa '||to_char(p_cod_causa)||' no registrada');
END;
BEGIN
   if inserting or updating then
      prg_obt_ge_parametro(:new.parametro, v_gparam);
      --- Verificar que el parámetro corresponda a la tabla de entes
      if v_gparam.tab_relacion <> 'GE_PAR_CAUSALES' then
         raise_application_error(-20000,
         'El parámetro '||:new.parametro||' no corresponde a esta tabla');
      end if;
      --- Verificar tipo de causa
      v_tipo := lf_obt_tip_causa(:new.cod_causa);
      if trim(v_gparam.referencia) <> v_tipo then
         raise_application_error(-20000,
         'Parametro '||:new.parametro||' no corresponde al tipo de causa '||v_tipo);
      end if;
   end if;
END;
/

