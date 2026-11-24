create or replace function it.FUP_VAL_CTA_VENCER(P_COD_PERSONA    BA_PERSONAS.COD_PERSONA%TYPE,  --Código de Persona
                                              P_NRO_CUENTA     GE_CUENTAS.NRO_CUENTA%TYPE default null,    --Número de Cuenta
                                              P_COD_MODALIDAD  GE_MODALIDADES.COD_MODALIDAD%TYPE default null,    --Código de Modalidad
                                              P_FECHA          GE_CALENDARIOS.FEC_ACTUAL%type default null)--Fecha Vencimiento
                                              return varchar is
  ---El objetivo de esta función es indicar si una persona o cuenta tiene vencimiento en la sig fecha habil o fecha que se reciba
  v_ind_cta_vencer        varchar2(1);  -- indica que si existe cuenta a vencer
  v_fecha     GE_CALENDARIOS.FEC_ACTUAL%type := nvl(P_FECHA,to_date('01012000','ddmmyyyy'));

begin
  -- Busco los datos de atrasos en las cuentas que tiene el client
 begin
  IF p_cod_modalidad is not NULL then
     SELECT distinct 'S'
       INTO v_ind_cta_vencer
       from ge_cta_clientes g, pr_cta_prestamos p, pr_cuotas c
      WHERE g.nro_cuenta = p.nro_cuenta
        and g.relacion = 'P'
        and p.nro_cuenta = c.nro_cuenta
        and g.cod_persona = p_cod_persona
        and g.nro_cuenta = nvl(p_nro_cuenta, g.nro_cuenta)
        and c.fec_vencimiento >= v_fecha
        and p.cod_modalidad = p_cod_modalidad
        and c.estado <> 'N'
        and exists (Select 0
                      from ge_est_cuentas c
                     where c.cod_modulo = p.cod_modulo
                       and c.cod_modalidad = p.cod_modalidad
                       and c.estado = p.estado
                       and c.activo = 'S');
  ELSE
     SELECT distinct 'S'
       INTO v_ind_cta_vencer
       from ge_cta_clientes g, pr_cta_prestamos p, pr_cuotas c
      WHERE g.nro_cuenta = p.nro_cuenta
        and g.relacion = 'P'
        and p.nro_cuenta = c.nro_cuenta
        and g.cod_persona = p_cod_persona
        and g.nro_cuenta = nvl(p_nro_cuenta, g.nro_cuenta)
        and c.fec_vencimiento >= v_fecha
        and p.cod_modalidad != 608
        and c.estado <> 'N'
        and exists (Select 0
                      from ge_est_cuentas c
                     where c.cod_modulo = p.cod_modulo
                       and c.cod_modalidad = p.cod_modalidad
                       and c.estado = p.estado
                       and c.activo = 'S');
  END IF;
 exception
   when no_data_found then
     v_ind_cta_vencer := 'N';
   when others then
     v_ind_cta_vencer := 'N';
 end;
  return nvl(v_ind_cta_vencer, 'N');

exception
  when others then
    raise_application_error(-20000, 'FUP_VAL_CTA_VENCER Cliente: ' ||P_COD_PERSONA||'-'||sqlerrm);
end FUP_VAL_CTA_VENCER;
/

