CREATE OR REPLACE PROCEDURE IT.PRP_INS_MOV_CAN_RES4
(p_fecha date default null,
p_hora in varchar2 default null,
p_cod_usuario in varchar2 default null,
p_nro_cuenta in varchar2 default null,
p_nro_sol_nueva in varchar2 default null,
p_act_inventario in varchar2 default 'N')
IS
--Guarda los movimientos de re4 para posterior afectacion en cobro de cuoAS
v_fec_actual DATE := pag_cal.fu_obt_fec_actual(6);
v_nro_cuenta GE_cuentas.nro_cuenta%type;
v_fec_valor date;
v_lugar varchar2(3000);
v_hora  ge_movimientos.hora%type := to_char(sysdate, 'HH24:MI:SS');
v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
v_mon_ges_cobro number(18,2);
v_mon_ges_impuesto number(18,2);
v_mon_cargo number(18,2);
v_cod_mon_local        varchar2(10):=pag_gen.FU_OBT_MON_LOCAL;
v_max_secuencia number(18);
v_mto_dev_suspenso number(18,2);
v_nro_sol_nueva number(18);
v_nro_sec_ultimo number(18);
v_es_moratorio varchar2(1):='N';
v_exi_registro varchar2(1);
v_tie_cobranza VARCHAR2(1):='N';
v_tie_dev_suspenso VARCHAR2(1):='N';
v_existe  varchar2(1):='N';

v_mto_sobregiro number(18,2);
v_mon_ges_sobregiro number(18,2);
--Movimientos del día
cursor c_movimientos is
select a.*
    from ge_movimientos a
         where a.fecha = p_fecha
           and a.hora= p_hora
           and a.cod_usuario= p_cod_usuario
           and a.reversado = 'N'
           and a.nro_cuenta=p_nro_cuenta
            order by a.fecha, a.hora,a.nro_secuencia;

cursor c_mov_historico is
select a.*
    from pr_movimientos_his a
         where a.fecha = p_fecha
           and a.hora= p_hora
           and a.cod_usuario= p_cod_usuario
           and a.nro_cuenta=p_nro_cuenta
           order by a.fecha, a.hora,a.nro_secuencia;
           
cursor c_mov_historico_cc is
select a.*
    from cc_movimientos_his a
         where a.fecha = p_fecha
           and a.hora= p_hora
           and a.cod_usuario= p_cod_usuario
           and a.nro_cuenta=p_nro_cuenta
           and a.cod_tra_padre=550
           and a.Cod_Transaccion=550
           order by a.fecha, a.hora,a.nro_secuencia;           
--Tabla de Inventario           
CURSOR c_cur_datos_2 IS
 select a.nro_cuenta nro_cuenta, a.fec_insercion fec_insercion,a.usu_insercion usu_insercion,a.nro_sol_nueva,
 a.mto_dev_suspenso, a.sal_inv_sobregiro, a.inv_sobregiro
   from PR_CTA_PRE_REF_RES4 a
   where a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
     and a.nro_sol_nueva= nvl(v_nro_sol_nueva,a.nro_sol_nueva);          


BEGIN
   Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:= 1; pae_cnf.G_PROGRAMA := 'GPPROFIN';  End;

if p_fecha <> v_fec_actual then
  --Tomamos del historico
  for i in c_mov_historico loop
        v_lugar:='Ins.Mov_His:'||i.nro_cuenta||' Fecha:'|| i.fecha||' Hora:'||i.hora;
        v_es_moratorio:='N';
        begin
         select 'S'
           into v_es_moratorio
            from ge_transacciones x
              where x.cod_transaccion= i.cod_transaccion
                and x.cod_modulo= i.cod_modulo
                and x.cod_modalidad= i.cod_modalidad
                and x.descripcion like 'MORA%';
        exception
         when no_data_found then
             v_es_moratorio:='N';
         when others then
             v_es_moratorio:='N';
        end;
        v_existe:='N';
           --Devengado en Suspenso
        if ((i.cod_tra_padre= 900 and i.cod_transaccion is null) or
           --Cobranza
           (i.cod_tra_padre in (359,360) and i.Cod_Transaccion=7712) or
           --Punitorio
           (i.cod_tra_padre in (359,360) and i.Cod_Transaccion=849) or
           --Moratorio
           (v_es_moratorio='S'))    then

           --Para COB/PUN/MOR
           begin
             select 'S'
               into v_existe
                from pr_movimientos_res4 w
                  where w.fecha= i.fecha 
                        and w.hora= i.hora
                        --and w.nro_secuencia= i.nro_secuencia
                        and w.nro_cuenta= i.nro_cuenta
                        and w.Cod_Transaccion= i.cod_transaccion
                        and w.concepto= i.concepto
                        and w.cod_tra_padre in (359,360);
            exception
             when no_data_found then
                 v_existe:='N';
             when too_many_rows then
                 v_existe:='S';
             when others then
                 v_existe:='N';
            end;
           --Para Devengado en suspenso
           if v_existe='N' and i.cod_tra_padre= 900 then
               --Buscamos si ya no insertó
                       begin
                         select 'S'
                           into v_existe
                            from pr_movimientos_res4 w
                              where  w.fecha= i.fecha 
                                     and w.hora= i.hora
                                     --and w.nro_secuencia= i.nro_secuencia
                                     and w.nro_cuenta= i.nro_cuenta
                                     and w.cod_tra_padre=i.cod_tra_padre
                                     and w.cod_rubro= i.cod_rubro
                                     and w.tip_mov_rubro= i.tip_mov_rubro;
                        exception
                         when no_data_found then
                             v_existe:='N';
                         when too_many_rows then
                             v_existe:='S';
                         when others then
                             v_existe:='N';
                        end;
           end if;

           if v_existe='N' then

              insert into pr_movimientos_res4(fecha,
                            hora,
                            cod_usuario,
                            nro_secuencia,
                            fec_valor,
                            monto,
                            nro_cuenta,
                            cod_moneda,
                            cod_oficina,
                            cod_error,
                            cod_retencion,
                            fec_fin_retencion,
                            est_cuenta,
                            estado,
                            cod_causa,
                            cod_banco,
                            cod_ofi_origen,
                            concepto,
                            cod_tasa,
                            val_tasa,
                            cod_rubro,
                            cod_ref_cambio,
                            reversado,
                            cod_usu_reversion,
                            hor_reversion,
                            emi_aviso,
                            cod_tra_padre,
                            cod_mod_padre,
                            cod_mad_padre,
                            cod_transaccion,
                            cod_modulo,
                            cod_modalidad,
                            mto_equ_local,
                            nro_caja,
                            cotizacion,
                            cod_bco_central,
                            nro_documento,
                            nro_documento2,
                            nro_documento3,
                            nro_documento4,
                            protegido,
                            cod_autorizacion,
                            cod_usu_autorizador,
                            usu_insercion,
                            fec_insercion,
                            usu_modificacion,
                            fec_modificacion,
                            tip_mov_rubro,
                            cod_tip_ope_cambio,
                            referencia,
                            cod_persona,
                            cod_sit_contable)
                     values(i.fecha,
                            i.hora,
                            i.cod_usuario,
                            i.nro_secuencia,
                            i.fec_valor,
                            i.monto,
                            i.nro_cuenta,
                            i.cod_moneda,
                            i.cod_oficina,
                            i.cod_error,
                            i.cod_retencion,
                            i.fec_fin_retencion,
                            i.est_cuenta,
                            i.estado,
                            i.cod_causa,
                            i.cod_banco,
                            i.cod_ofi_origen,
                            i.concepto,
                            i.cod_tasa,
                            i.val_tasa,
                            i.cod_rubro,
                            i.cod_ref_cambio,
                            i.reversado,
                            i.cod_usu_reversion,
                            i.hor_reversion,
                            i.emi_aviso,
                            i.cod_tra_padre,
                            i.cod_mod_padre,
                            i.cod_mad_padre,
                            i.cod_transaccion,
                            i.cod_modulo,
                            i.cod_modalidad,
                            i.mto_equ_local,
                            i.nro_caja,
                            i.cotizacion,
                            i.cod_bco_central,
                            i.nro_documento,
                            i.nro_documento2,
                            i.nro_documento3,
                            i.nro_documento4,
                            i.protegido,
                            i.cod_autorizacion,
                            i.cod_usu_autorizador,
                            i.usu_insercion,
                            i.fec_insercion,
                            i.usu_modificacion,
                            i.fec_modificacion,
                            i.tip_mov_rubro,
                            i.cod_tip_ope_cambio,
                            i.referencia,
                            i.cod_persona,
                            i.cod_sit_contable);
            end if;
          end if;
        
     end loop;
     
   --Tomamos de sobregiro historico
  for i in c_mov_historico_cc loop 
        --Verificamos si ya existe en la tabla maestro, sino cargamos
       v_exi_registro:='N';
       begin
          select 'S'
           into v_exi_registro
             from pr_movimientos_res4 s
               where s.fecha= i.fecha 
                 and s.hora= i.hora
                 --and s.nro_secuencia= i.nro_secuencia
                 and s.nro_cuenta= i.nro_cuenta
                 and s.Cod_Transaccion= i.cod_transaccion;

       exception
          when no_data_found then
             v_exi_registro:='N';
          when others then
              v_exi_registro:='S';
       end;
  
  
      if v_exi_registro='N' THEN 
      insert into pr_movimientos_res4(fecha,
                            hora,
                            cod_usuario,
                            nro_secuencia,
                            fec_valor,
                            monto,
                            nro_cuenta,
                            cod_moneda,
                            cod_oficina,
                            cod_error,
                            cod_retencion,
                            fec_fin_retencion,
                            est_cuenta,
                            estado,
                            cod_causa,
                            cod_banco,
                            cod_ofi_origen,
                            concepto,
                            cod_tasa,
                            val_tasa,
                            cod_rubro,
                            cod_ref_cambio,
                            reversado,
                            cod_usu_reversion,
                            hor_reversion,
                            emi_aviso,
                            cod_tra_padre,
                            cod_mod_padre,
                            cod_mad_padre,
                            cod_transaccion,
                            cod_modulo,
                            cod_modalidad,
                            mto_equ_local,
                            nro_caja,
                            cotizacion,
                            cod_bco_central,
                            nro_documento,
                            nro_documento2,
                            nro_documento3,
                            nro_documento4,
                            protegido,
                            cod_autorizacion,
                            cod_usu_autorizador,
                            usu_insercion,
                            fec_insercion,
                            usu_modificacion,
                            fec_modificacion,
                            tip_mov_rubro,
                            cod_tip_ope_cambio,
                            referencia,
                            cod_persona,
                            cod_sit_contable)
                     values(i.fecha,
                            i.hora,
                            i.cod_usuario,
                            i.nro_secuencia,
                            i.fec_valor,
                            i.monto,
                            i.nro_cuenta,
                            i.cod_moneda,
                            i.cod_oficina,
                            i.cod_error,
                            i.cod_retencion,
                            i.fec_fin_retencion,
                            i.est_cuenta,
                            i.estado,
                            i.cod_causa,
                            i.cod_banco,
                            i.cod_ofi_origen,
                            i.concepto,
                            i.cod_tasa,
                            i.val_tasa,
                            i.cod_rubro,
                            i.cod_ref_cambio,
                            i.reversado,
                            i.cod_usu_reversion,
                            i.hor_reversion,
                            i.emi_aviso,
                            i.cod_tra_padre,
                            i.cod_mod_padre,
                            i.cod_mad_padre,
                            i.cod_transaccion,
                            i.cod_modulo,
                            i.cod_modalidad,
                            i.mto_equ_local,
                            i.nro_caja,
                            i.cotizacion,
                            i.cod_bco_central,
                            i.nro_documento,
                            i.nro_documento2,
                            i.nro_documento3,
                            i.nro_documento4,
                            i.protegido,
                            i.cod_autorizacion,
                            i.cod_usu_autorizador,
                            i.usu_insercion,
                            i.fec_insercion,
                            i.usu_modificacion,
                            i.fec_modificacion,
                            i.tip_mov_rubro,
                            i.cod_tip_ope_cambio,
                            i.referencia,
                            i.cod_persona,
                            i.cod_sit_contable);
         end if;
    end loop; 
  if p_act_inventario ='S' then
        --- Tabla Espejo 2
        v_nro_sol_nueva:=null;
        v_nro_sol_nueva:=p_nro_sol_nueva;
              FOR w IN c_cur_datos_2 LOOP
                  v_mon_ges_cobro:=0;
                  v_mon_ges_impuesto:=0;
                  v_mon_cargo:=0;
                  v_mto_dev_suspenso:=0;
                  v_mon_ges_sobregiro:=0;
                  v_lugar:='Act.Esp.1- Intereses:'||w.nro_cuenta;
                  v_mto_dev_suspenso:= nvl(w.mto_dev_suspenso,0);
                  --Inventario de Interes
                  if nvl(v_mto_dev_suspenso,0) > 0 then
                      update PR_CTA_PRE_REF_RES4 a
                      set a.inv_interes=nvl(a.inv_interes,0) + nvl(v_mto_dev_suspenso,0),
                          a.sal_inv_interes=nvl(a.sal_inv_interes,0) + nvl(v_mto_dev_suspenso,0)
                      where a.nro_cuenta=w.nro_cuenta
                        and a.nro_sol_nueva=w.nro_sol_nueva;
                  end if;
                  v_lugar:='Act.Esp.1- Ges_Ccobranza:'||w.nro_cuenta;
                  --Gestion de Cobranza
                  begin
                  select sum(a.monto)
                    into v_mon_ges_cobro
                     from pr_movimientos_his a
                       where 
                        a.fecha= p_fecha
                        and a.hora= p_hora
                        and a.cod_usuario= p_cod_usuario
                        and a.nro_cuenta= p_nro_cuenta
                        and a.cod_transaccion=7712
                        and a.cod_tra_padre in (359,360)
                        and nvl(a.reversado,'N')='N';
                  exception
                    when no_data_found then
                      v_mon_ges_cobro:=0;
                  end;

                  if  nvl(v_mon_ges_cobro,0)> 0 then
                      update PR_CTA_PRE_REF_RES4 b
                       set b.inv_ges_cobranza= nvl(b.inv_ges_cobranza,0)+ nvl(v_mon_ges_cobro,0),
                           b.sal_inv_ges_cobranza=nvl(b.sal_inv_ges_cobranza,0)+ nvl(v_mon_ges_cobro,0)
                        where b.nro_cuenta= w.nro_cuenta
                          and b.nro_sol_nueva=w.nro_sol_nueva;
                          v_tie_cobranza:= 'S';
                  end if;

                  v_lugar:='Act.Esp.2- Impuesto:'||w.nro_cuenta;
                  --Impuestos
                   begin
                    select sum(a.monto)
                      into v_mon_ges_impuesto
                       from pr_movimientos_his a
                         where  a.fecha= p_fecha
                            and a.hora= p_hora
                            and a.cod_usuario= p_cod_usuario
                            and a.nro_cuenta= p_nro_cuenta
                            and nvl(a.val_tasa,0) in (5,10)
                            and a.cod_tra_padre in (359,360)
                            and nvl(a.reversado,'N')='N';
                    exception
                      when no_data_found then
                        v_mon_ges_impuesto:=0;
                    end;

                    if  nvl(v_mon_ges_impuesto,0)> 0 then
                        update PR_CTA_PRE_REF_RES4 b
                         set b.inv_mto_impuesto=nvl(b.inv_mto_impuesto,0) + nvl(v_mon_ges_impuesto,0)
                          where b.nro_cuenta= w.nro_cuenta
                           and b.nro_sol_nueva=w.nro_sol_nueva;
                    end if;
                   --Cargos
                   v_lugar:='Act.Esp.2- Cargos:'||w.nro_cuenta;
                   begin
                    select sum(a.monto)
                      into v_mon_cargo
                       from pr_movimientos_his a
                         where  a.fecha= p_fecha
                            and a.hora= p_hora
                            and a.cod_usuario= p_cod_usuario
                            and a.nro_cuenta= p_nro_cuenta
                            and a.Cod_Transaccion in (1520,1521)
                            and a.cod_tra_padre in (359,360)
                           and nvl(a.reversado,'N')='N';
                    exception
                      when no_data_found then
                        v_mon_cargo:=0;
                    end;

                    if  nvl(v_mon_cargo,0)> 0 then
                        update PR_CTA_PRE_REF_RES4 b
                         set b.inv_mto_cargo= nvl(b.inv_mto_cargo,0)+ nvl(v_mon_cargo,0)
                          where b.nro_cuenta= w.nro_cuenta
                             and b.nro_sol_nueva=w.nro_sol_nueva;
                    end if;
                    IF  NVL(v_mto_dev_suspenso,0) > 0 THEN
                        v_tie_dev_suspenso:='S';
                    END IF;
                  v_lugar:='Act.Esp.2- Sobregiro:'||w.nro_cuenta;  
                  --Sobregiro
                  begin
                  select a.monto
                    into v_mon_ges_sobregiro
                     from cc_movimientos_his a
                       where 
                         a.fecha= p_fecha
                        and a.hora= p_hora
                        and a.cod_usuario= p_cod_usuario
                        and a.nro_cuenta= p_nro_cuenta
                        and a.cod_transaccion=550
                        and a.cod_tra_padre =550
                        and nvl(a.reversado,'N')='N';
                  exception
                    when no_data_found then
                      v_mon_ges_sobregiro:=0;
                  end;
                    --Sobregiro
                     if nvl(v_mon_ges_sobregiro,0) > 0 then
                        update PR_CTA_PRE_REF_RES4 b
                         set b.inv_sobregiro= nvl(b.inv_sobregiro,0)+ nvl(v_mon_ges_sobregiro,0),
                             b.sal_inv_sobregiro= nvl(b.sal_inv_sobregiro,0)+ nvl(v_mon_ges_sobregiro,0)
                          where b.nro_cuenta= w.nro_cuenta
                             and b.nro_sol_nueva=w.nro_sol_nueva;
                     end if;
                     
                    v_lugar:='Act.Esp.2- Inventariar o No:'||w.nro_cuenta;  
                    --Sino tiene interes y gestion de cobranza, ni sobregiro, no se va a inventariar
                    if nvl(v_mon_ges_cobro,0)= 0 and nvl(v_mto_dev_suspenso,0) = 0 
                      and nvl(v_mon_ges_sobregiro,0) = 0 then
                        update PR_CTA_PRE_REF_RES4 b
                         set b.Inventariar='N'
                          where b.nro_cuenta= w.nro_cuenta
                           and b.nro_sol_nueva=w.nro_sol_nueva;
                    end if;
              END LOOP;
  end if;  
     
     
     
else
     --Tomamos del día
    for i in c_movimientos loop
     
            --Para Prestamos
         if i.cod_modulo= 6 then
              v_existe:='N';
              v_lugar:='Ins.Mov.:'||i.nro_cuenta||' Fecha:'|| i.fecha||' Hora:'||i.hora;
              v_es_moratorio:='N';
              begin
               select 'S'
                 into v_es_moratorio
                  from ge_transacciones x
                    where x.cod_transaccion= i.cod_transaccion
                      and x.cod_modulo= i.cod_modulo
                      and x.cod_modalidad= i.cod_modalidad
                      and x.descripcion like 'MORA%';
              exception
               when no_data_found then
                   v_es_moratorio:='N';
               when others then
                   v_es_moratorio:='N';
              end;
                 --Devengado en Suspenso
              if ((i.cod_tra_padre= 900 and i.cod_transaccion is null) or
                 --Cobranza
                 (i.cod_tra_padre in (359,360) and i.Cod_Transaccion=7712) or
                 --Punitorio
                 (i.cod_tra_padre in (359,360) and i.Cod_Transaccion=849) or
                 --Moratorio
                 (v_es_moratorio='S'))    then
                   --Para COB/PUN/MOR
                   begin
                     select 'S'
                       into v_existe
                        from pr_movimientos_res4 w
                          where  w.fecha= i.fecha 
                                 and w.hora= i.hora
                                 --and w.nro_secuencia= i.nro_secuencia
                                 and w.nro_cuenta= i.nro_cuenta
                                 and w.Cod_Transaccion= i.cod_transaccion
                                 and w.concepto= i.concepto
                                 and w.cod_tra_padre in (359,360);
                    exception
                     when no_data_found then
                         v_existe:='N';
                     when too_many_rows then
                         v_existe:='S';
                     when others then
                         v_existe:='N';
                    end;
                  --Para Devengado en suspenso
                   if v_existe='N' and i.cod_tra_padre= 900 then
                      --Buscamos si ya no insertó
                       begin
                         select 'S'
                           into v_existe
                            from pr_movimientos_res4 w
                              where  w.fecha= i.fecha 
                                     and w.hora= i.hora
                                     --and w.nro_secuencia= i.nro_secuencia
                                     and w.nro_cuenta= i.nro_cuenta
                                     and w.cod_tra_padre=i.cod_tra_padre
                                     and w.cod_rubro= i.cod_rubro
                                     and w.tip_mov_rubro= i.tip_mov_rubro;
                        exception
                         when no_data_found then
                             v_existe:='N';
                         when too_many_rows then
                             v_existe:='S';
                         when others then
                             v_existe:='N';
                        end;
                   end if;
              if v_existe='N' then
                 insert into pr_movimientos_res4(fecha,
                            hora,
                            cod_usuario,
                            nro_secuencia,
                            fec_valor,
                            monto,
                            nro_cuenta,
                            cod_moneda,
                            cod_oficina,
                            cod_error,
                            cod_retencion,
                            fec_fin_retencion,
                            est_cuenta,
                            estado,
                            cod_causa,
                            cod_banco,
                            cod_ofi_origen,
                            concepto,
                            cod_tasa,
                            val_tasa,
                            cod_rubro,
                            cod_ref_cambio,
                            reversado,
                            cod_usu_reversion,
                            hor_reversion,
                            emi_aviso,
                            cod_tra_padre,
                            cod_mod_padre,
                            cod_mad_padre,
                            cod_transaccion,
                            cod_modulo,
                            cod_modalidad,
                            mto_equ_local,
                            nro_caja,
                            cotizacion,
                            cod_bco_central,
                            nro_documento,
                            nro_documento2,
                            nro_documento3,
                            nro_documento4,
                            protegido,
                            cod_autorizacion,
                            cod_usu_autorizador,
                            usu_insercion,
                            fec_insercion,
                            usu_modificacion,
                            fec_modificacion,
                            tip_mov_rubro,
                            cod_tip_ope_cambio,
                            referencia,
                            cod_persona,
                            cod_sit_contable,
                            nro_conciliacion)
                     values(i.fecha,
                            i.hora,
                            i.cod_usuario,
                            i.nro_secuencia,
                            i.fec_valor,
                            i.monto,
                            i.nro_cuenta,
                            i.cod_moneda,
                            i.cod_oficina,
                            i.cod_error,
                            i.cod_retencion,
                            i.fec_fin_retencion,
                            i.est_cuenta,
                            i.estado,
                            i.cod_causa,
                            i.cod_banco,
                            i.cod_ofi_origen,
                            i.concepto,
                            i.cod_tasa,
                            i.val_tasa,
                            i.cod_rubro,
                            i.cod_ref_cambio,
                            i.reversado,
                            i.cod_usu_reversion,
                            i.hor_reversion,
                            i.emi_aviso,
                            i.cod_tra_padre,
                            i.cod_mod_padre,
                            i.cod_mad_padre,
                            i.cod_transaccion,
                            i.cod_modulo,
                            i.cod_modalidad,
                            i.mto_equ_local,
                            i.nro_caja,
                            i.cotizacion,
                            i.cod_bco_central,
                            i.nro_documento,
                            i.nro_documento2,
                            i.nro_documento3,
                            i.nro_documento4,
                            i.protegido,
                            i.cod_autorizacion,
                            i.cod_usu_autorizador,
                            i.usu_insercion,
                            i.fec_insercion,
                            i.usu_modificacion,
                            i.fec_modificacion,
                            i.tip_mov_rubro,
                            i.cod_tip_ope_cambio,
                            i.referencia,
                            i.cod_persona,
                            i.cod_sit_contable,
                            i.nro_conciliacion);
              
             
            end if;
        --Para sobregiros
      elsif i.cod_modulo= 4 then
         if i.cod_modalidad= 41 and i.Cod_Tra_Padre=550 and i.cod_transaccion=550 then
                        insert into pr_movimientos_res4(fecha,
                            hora,
                            cod_usuario,
                            nro_secuencia,
                            fec_valor,
                            monto,
                            nro_cuenta,
                            cod_moneda,
                            cod_oficina,
                            cod_error,
                            cod_retencion,
                            fec_fin_retencion,
                            est_cuenta,
                            estado,
                            cod_causa,
                            cod_banco,
                            cod_ofi_origen,
                            concepto,
                            cod_tasa,
                            val_tasa,
                            cod_rubro,
                            cod_ref_cambio,
                            reversado,
                            cod_usu_reversion,
                            hor_reversion,
                            emi_aviso,
                            cod_tra_padre,
                            cod_mod_padre,
                            cod_mad_padre,
                            cod_transaccion,
                            cod_modulo,
                            cod_modalidad,
                            mto_equ_local,
                            nro_caja,
                            cotizacion,
                            cod_bco_central,
                            nro_documento,
                            nro_documento2,
                            nro_documento3,
                            nro_documento4,
                            protegido,
                            cod_autorizacion,
                            cod_usu_autorizador,
                            usu_insercion,
                            fec_insercion,
                            usu_modificacion,
                            fec_modificacion,
                            tip_mov_rubro,
                            cod_tip_ope_cambio,
                            referencia,
                            cod_persona,
                            cod_sit_contable,
                            nro_conciliacion)
                     values(i.fecha,
                            i.hora,
                            i.cod_usuario,
                            i.nro_secuencia,
                            i.fec_valor,
                            i.monto,
                            i.nro_cuenta,
                            i.cod_moneda,
                            i.cod_oficina,
                            i.cod_error,
                            i.cod_retencion,
                            i.fec_fin_retencion,
                            i.est_cuenta,
                            i.estado,
                            i.cod_causa,
                            i.cod_banco,
                            i.cod_ofi_origen,
                            i.concepto,
                            i.cod_tasa,
                            i.val_tasa,
                            i.cod_rubro,
                            i.cod_ref_cambio,
                            i.reversado,
                            i.cod_usu_reversion,
                            i.hor_reversion,
                            i.emi_aviso,
                            i.cod_tra_padre,
                            i.cod_mod_padre,
                            i.cod_mad_padre,
                            i.cod_transaccion,
                            i.cod_modulo,
                            i.cod_modalidad,
                            i.mto_equ_local,
                            i.nro_caja,
                            i.cotizacion,
                            i.cod_bco_central,
                            i.nro_documento,
                            i.nro_documento2,
                            i.nro_documento3,
                            i.nro_documento4,
                            i.protegido,
                            i.cod_autorizacion,
                            i.cod_usu_autorizador,
                            i.usu_insercion,
                            i.fec_insercion,
                            i.usu_modificacion,
                            i.fec_modificacion,
                            i.tip_mov_rubro,
                            i.cod_tip_ope_cambio,
                            i.referencia,
                            i.cod_persona,
                            i.cod_sit_contable,
                            i.nro_conciliacion);
        end if;
      end if;   
     end if;   
            
   end loop;
 if p_act_inventario ='S' then 

         v_nro_sol_nueva:=null;
          v_nro_sol_nueva:=p_nro_sol_nueva;
             --- Tabla Espejo 2
          FOR w IN c_cur_datos_2 LOOP
              v_mon_ges_cobro:=0;
              v_mon_ges_impuesto:=0;
              v_mon_cargo:=0;
              v_mto_dev_suspenso:=0;
              v_mon_ges_sobregiro:=0;
              v_lugar:='Act.Esp.2- Gestion de Cobranza:'||w.nro_cuenta;
              v_lugar:='Act.Esp.1- Intereses:'||w.nro_cuenta;
              v_mto_dev_suspenso:= nvl(w.mto_dev_suspenso,0);
              --Inventario de Interes
              if nvl(v_mto_dev_suspenso,0) > 0 then
                  update PR_CTA_PRE_REF_RES4 a
                  set a.inv_interes=nvl(a.inv_interes,0) + nvl(v_mto_dev_suspenso,0),
                      a.sal_inv_interes=nvl(a.sal_inv_interes,0) + nvl(v_mto_dev_suspenso,0)
                  where a.nro_cuenta=w.nro_cuenta
                    and a.nro_sol_nueva=w.nro_sol_nueva;
              end if;
              --Gestion de Cobranza
              begin
              select sum(a.monto)
                into v_mon_ges_cobro
                 from ge_movimientos a
                   where a.cod_transaccion=7712
                    and a.nro_cuenta= w.nro_cuenta
                    and a.cod_tra_padre in (359,360)
                    and nvl(a.reversado,'N')='N';
              exception
                when no_data_found then
                  v_mon_ges_cobro:=0;
              end;

              if  nvl(v_mon_ges_cobro,0)> 0 then
                  update PR_CTA_PRE_REF_RES4 b
                   set b.inv_ges_cobranza= nvl(b.inv_ges_cobranza,0)+ nvl(v_mon_ges_cobro,0),
                       b.sal_inv_ges_cobranza=nvl(b.sal_inv_ges_cobranza,0)+ nvl(v_mon_ges_cobro,0)
                    where b.nro_cuenta= w.nro_cuenta
                      and b.nro_sol_nueva=w.nro_sol_nueva;
                      v_tie_cobranza:= 'S';
              end if;

              v_lugar:='Act.Esp.2- Impuesto:'||w.nro_cuenta;
              --Impuestos
               begin
                select sum(a.monto)
                  into v_mon_ges_impuesto
                   from ge_movimientos a
                     where nvl(a.val_tasa,0) in (5,10)
                      and a.nro_cuenta= w.nro_cuenta
                      and a.cod_tra_padre in (359,360)
                      and nvl(a.reversado,'N')='N';
                exception
                  when no_data_found then
                    v_mon_ges_impuesto:=0;
                end;

                if  nvl(v_mon_ges_impuesto,0)> 0 then
                    update PR_CTA_PRE_REF_RES4 b
                     set b.inv_mto_impuesto=nvl(b.inv_mto_impuesto,0) + nvl(v_mon_ges_impuesto,0)
                      where b.nro_cuenta= w.nro_cuenta
                       and b.nro_sol_nueva=w.nro_sol_nueva;
                end if;
               --Cargos
               v_lugar:='Act.Esp.2- Cargos:'||w.nro_cuenta;
               begin
                select sum(a.monto)
                  into v_mon_cargo
                   from ge_movimientos a
                     where a.Cod_Transaccion in (1520,1521)
                      and a.nro_cuenta= w.nro_cuenta
                       and a.cod_tra_padre in (359,360)
                      and nvl(a.reversado,'N')='N';
                exception
                  when no_data_found then
                    v_mon_cargo:=0;
                end;

                if  nvl(v_mon_cargo,0)> 0 then
                    update PR_CTA_PRE_REF_RES4 b
                     set b.inv_mto_cargo= nvl(b.inv_mto_cargo,0)+ nvl(v_mon_cargo,0)
                      where b.nro_cuenta= w.nro_cuenta
                         and b.nro_sol_nueva=w.nro_sol_nueva;
                end if;
                IF  NVL(v_mto_dev_suspenso,0) > 0 THEN
                    v_tie_dev_suspenso:='S';
                END IF;
              v_lugar:='Act.Esp.2- Sobregiro:'||w.nro_cuenta;  
              --Sobregiro
              begin
              select a.monto
                into v_mon_ges_sobregiro
                 from ge_movimientos a
                   where a.cod_transaccion=550
                    and a.nro_cuenta= w.nro_cuenta
                    and a.cod_tra_padre =550
                    and nvl(a.reversado,'N')='N';
              exception
                when no_data_found then
                  v_mon_ges_sobregiro:=0;
              end;
                --Sobregiro
                 if nvl(v_mon_ges_sobregiro,0) > 0 then
                    update PR_CTA_PRE_REF_RES4 b
                     set b.inv_sobregiro= nvl(b.inv_sobregiro,0)+ nvl(v_mon_ges_sobregiro,0),
                         b.sal_inv_sobregiro= nvl(b.sal_inv_sobregiro,0)+ nvl(v_mon_ges_sobregiro,0)
                      where b.nro_cuenta= w.nro_cuenta
                         and b.nro_sol_nueva=w.nro_sol_nueva;
                 end if;
                 
                v_lugar:='Act.Esp.2- Inventariar o No:'||w.nro_cuenta;  
                --Sino tiene interes y gestion de cobranza, ni sobregiro, no se va a inventariar
                if nvl(v_mon_ges_cobro,0)= 0 and nvl(v_mto_dev_suspenso,0) = 0 
                  and nvl(v_mon_ges_sobregiro,0) = 0 then
                    update PR_CTA_PRE_REF_RES4 b
                     set b.Inventariar='N'
                      where b.nro_cuenta= w.nro_cuenta
                       and b.nro_sol_nueva=w.nro_sol_nueva;

                end if;
          END LOOP;
   end if;
   
end if;


EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. Ins.Mov.Canc.RE4.: '||v_lugar||'-'||SQLERRM);
END PRP_INS_MOV_CAN_RES4;
/

