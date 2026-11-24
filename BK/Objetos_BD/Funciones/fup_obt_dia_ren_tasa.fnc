CREATE OR REPLACE FUNCTION IT."FUP_OBT_DIA_REN_TASA" (P_COD_PERSONA IN VARCHAR2 --Código de la persona
                                                ) return number is
  v_dia_a_vencer number;
  v_fec_actual   date := pag_cal.fu_obt_fec_actual(6);
begin

  --Dias que faltan para la fecha de la Renegociación
  select max(nvl(p.fec_ren_tas_orig - v_fec_actual, 0))
    into v_dia_a_vencer
    from pr_cta_prestamos p, ge_cta_clientes cl
   where cl.cod_persona = p_cod_persona
     and cl.relacion = 'P'
     and p.nro_cuenta = cl.nro_cuenta
     and p.fec_ren_tas_orig > v_fec_actual
     and p.estado not in('N', 'I') 
     --and nvl(fug_obt_pardinamico('PRE_REAJUSTABLE',p.cod_modulo,p.cod_modalidad),'N') = 'S'
     ;

  return v_dia_a_vencer;

exception
  when no_data_found then
    return null;
  when others then
    return null;
end FUP_OBT_DIA_REN_TASA;
/

