CREATE OR REPLACE FUNCTION IT.FUE_CTR_FEC_FERIADO
 (P_FECHA IN BA_FERIADOS.FECHA%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 RETURN BOOLEAN
 IS

/* Controla si una fecha es feriado o no. */
FUNCTION LF_CTR_FEC_FERIADO
 (P_FECHA IN BA_FERIADOS.FECHA%TYPE
 )
 RETURN BOOLEAN;
v_fecha ba_feriados.fecha%type;

/* Controla si una fecha es feriado o no. */
FUNCTION LF_CTR_FEC_FERIADO
 (P_FECHA IN BA_FERIADOS.FECHA%TYPE
 )
 RETURN BOOLEAN
 IS
v_fecha ba_feriados.fecha%type;
BEGIN
   select fecha
   into v_fecha
   from ba_feriados
   where fecha = p_fecha
     and cod_oficina is null;
   return TRUE;
exception
   when no_data_found then
      return FALSE;
   when too_many_rows then
      return TRUE;
END;
BEGIN

   if p_cod_oficina is not null then
      select fecha
      into v_fecha
      from ba_feriados
      where fecha = p_fecha
      and cod_oficina = p_cod_oficina;
      return TRUE;
   else
      return lf_ctr_fec_feriado(p_fecha);
   end if;
exception
   when no_data_found then
      return lf_ctr_fec_feriado(p_fecha);
   when too_many_rows then
      return TRUE;
END;
/

