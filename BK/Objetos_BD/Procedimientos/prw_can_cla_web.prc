create or replace procedure it.prw_can_cla_web
 is
 -- DE-2036
 v_fec_actual date := pag_cal.fu_obt_fec_actual(1);
 v_cod_persona bw_ope_claves.cod_persona%type;
 v_dia_per_inactividad number;
 -- OMM 07/04/2016. Proceso para cancelar las claves de acceso de clientes sin producto activo.
 cursor c_clave is
      Select x.cod_persona cod_persona, x.tip_clave, 'F' Tip_persona
        from bw_ope_claves x
       where x.est_clave <> 'X'
         and x.cod_per_vinculada is null
         and not exists
       (Select 1
                from ge_cuentas a, ge_est_cuentas e, ge_cta_clientes c
               where a.cod_modulo = e.cod_modulo
                 and a.cod_modalidad = e.cod_modalidad
                 and a.estado = e.estado
                 and e.activo = 'S'
                 and a.nro_cuenta = c.nro_cuenta
                 and c.cod_persona = x.cod_persona
                 and c.relacion in ('P', 'O', 'Y')) -- Principal, Indistinta, Conjunta
      union all
      Select distinct x.cod_per_vinculada cod_persona,
                      x.tip_clave,
                      'J' Tip_persona
        from bw_ope_claves x
       where x.est_clave <> 'X'
         and x.cod_per_vinculada is not null
         and not exists
       (Select 1
                from ge_cuentas a, ge_est_cuentas e, ge_cta_clientes c
               where a.cod_modulo = e.cod_modulo
                 and a.cod_modalidad = e.cod_modalidad
                 and a.estado = e.estado
                 and e.activo = 'S'
                 and a.nro_cuenta = c.nro_cuenta
                 and c.cod_persona = x.cod_per_vinculada
                 and c.relacion = 'P'); -- Principal
function lf_dia_actividad(p_cod_persona varchar2, p_tipo char) return varchar2 is
  v_return char;
  v_dias number(10);
  v_max_fec_can date;
begin
        if p_tipo = 'F' then
               Select max(trunc(a.fec_cam_estado))
                 into v_max_fec_can
                 from ge_cuentas a, ge_est_cuentas e, ge_cta_clientes c
                where a.cod_modulo = e.cod_modulo
                  and a.cod_modalidad = e.cod_modalidad
                  and a.estado = e.estado
                  and e.activo = 'N'
                  and a.nro_cuenta = c.nro_cuenta
                  and c.cod_persona = p_cod_persona
                  and c.relacion in ('P', 'O', 'Y');
        else
               Select max(trunc(a.fec_cam_estado))
                 into v_max_fec_can
                 from ge_cuentas a, ge_est_cuentas e, ge_cta_clientes c
                where a.cod_modulo = e.cod_modulo
                  and a.cod_modalidad = e.cod_modalidad
                  and a.estado = e.estado
                  and e.activo = 'N'
                  and a.nro_cuenta = c.nro_cuenta
                  and c.cod_persona = p_cod_persona
                  and c.relacion = 'P';
        end if ;
        v_dias := (v_fec_actual - v_max_fec_can);
        if v_dias > v_dia_per_inactividad then
             v_return := 'S';
        else
             v_return := 'N';
        end if;
return v_return;
end;
Begin
   v_dia_per_inactividad := to_number(fug_obt_pardinamico('DIA_PER_INACTIVIDAD'));
   for c in c_clave loop
       v_cod_persona := c.cod_persona;
       if  c.tip_persona = 'F' then -- Para personas fisicas
         if lf_dia_actividad(c.cod_persona, 'F') = 'S' then -- Verifica si cumple con el limite de dias de inactividad
                  update bw_ope_claves a
                     set a.est_clave = 'X', -- Clave Cancelada
                         a.fec_cam_clave = sysdate
                  where a.cod_persona = v_cod_persona
                    and a.cod_per_vinculada is null
                    and a.tip_clave = c.tip_clave ;
          end if;
       else
          if lf_dia_actividad(c.cod_persona, 'J') = 'S' then -- Verifica si cumple con el limite de dias de inactividad
                  update bw_ope_claves a -- Para personas vinculadas a empresas
                     set a.est_clave = 'X', -- Clave Cancelada
                         a.fec_cam_clave = sysdate
                  where a.cod_per_vinculada = v_cod_persona
                    and a.tip_clave = c.tip_clave ;
            end if;
         end if ;
   end loop;
exception
    when others then
         raise_application_error(-20001,'En PRW_CAN_CLA_WEB al tratar de cancelar clave del cliente: '
                                 || v_cod_persona || '-' ||sqlerrm);
end;
/

