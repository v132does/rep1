create or replace function it.fug_obt_cli_informconf(p_cod_persona in ba_personas.cod_persona%type)
  return varchar2 is
  v_vigencia         number := to_number(fug_obt_pardinamico('FAD_VIG_INF_COMERCIALES'));
  v_respuesta        varchar2(500) := null;
  v_fec_ult_consulta date := null;
  --------------------------------------------------------
BEGIN
  BEGIN
    SELECT max(a.fec_consulta)
      INTO v_fec_ult_consulta
      FROM ge_eqf_solicitudes a, ge_eqf_faj_scoring b
     WHERE a.nro_solicitud = b.nro_solicitud
       AND (a.tip_servicio = 'INFORMCONF' and
           (b.faja is not null or a.nom_informe is not null))
       AND a.cod_persona = p_cod_persona;
  EXCEPTION
    WHEN others THEN
      v_fec_ult_consulta := null;
  END;

  IF trunc(pag_cal.FU_OBT_FEC_ACTUAL(1)) - trunc(v_fec_ult_consulta) <= v_vigencia THEN
    v_respuesta := PAG_EQF.FU_PRO_DAT_INFORMCONF(p_cod_persona, 'N', 99);
  END IF;

  ---------------------------------------------------------
  return(v_respuesta);
end fug_obt_cli_informconf;
/

