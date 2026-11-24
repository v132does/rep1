create or replace procedure it.prg_cam_oficina is
  v_nro_traspaso    ge_tra_cli_oficial.nro_traspaso%type;
  v_nro_orden    ge_tra_cli_oficial.nro_orden%type := 0;
  v_fecha    date := pag_cal.fu_obt_fec_actual(1);
  v_cod_persona  ba_personas.cod_persona%type ;
--  v_men            varchar2(1000) := null;

-- JUN/2018 - OMM Proceso de cambio de oficina.
  Cursor C_Clientes is
    Select a.cod_persona, a.cod_usu_ofi_ori, a.cod_usu_ofi_des,
           a.cod_ofi_origen, a.cod_ofi_destino 
     from GE_CAM_OFI_TMP a 
    Where nvl(a.procesado, 'N') <> 'S';

   cursor c_ctas (p_cod_persona  in  ba_personas.cod_persona%type) is
       Select c.nro_cuenta, c.cod_oficina, c.cod_modalidad, c.cod_modulo
       from ge_cta_clientes c, ge_est_cuentas e, ge_cuentas g
       where c.cod_persona = p_cod_persona
         and c.relacion = 'P'
         and c.nro_cuenta = g.nro_cuenta
         and c.cod_modulo = e.cod_modulo
         and c.cod_modalidad = e.cod_modalidad
         and g.estado = e.estado
         and e.activo = 'S';

PROCEDURE pr_ins_log(p_Clave IN VARCHAR2,
                     p_tipo IN VARCHAR2,
                     p_mad IN NUMBER,
                     p_observacion IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
         BEGIN
           insert into tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
                values (v_fecha, p_tipo, p_clave, p_mad, p_observacion);
        EXCEPTION
          WHEN OTHERS THEN
             null;
        END;

Begin
   begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; PAE_CNF.G_PROGRAMA := 'GPELICTA'; end;
   begin
     select S_NRO_TRASPASO.nextval
       into v_nro_traspaso
       from dual;
   exception
     when others then
       raise_application_error(-20000, 'No se puede obtener el número de secuencia. '||sqlerrm);
   end;
   
  -- sql_util.ejecute_dml('alter trigger TB_GE_CTA_CLIENTES DISABLE',v_men);
           
   for reg in C_Clientes loop
       v_cod_persona := reg.cod_persona ;
       begin
           v_nro_orden := nvl(v_nro_orden, 0) + 1;

           insert into ge_tra_cli_oficial ( nro_traspaso, nro_orden, fecha, cod_persona,
                                            cod_usu_ofi_des, cod_usu_ofi_ori, cod_programa )
                                   values ( v_nro_traspaso, v_nro_orden, v_fecha, v_cod_persona,
                                            reg.cod_usu_ofi_des, reg.cod_usu_ofi_ori, 'CAM_OFICINA');
         exception
           when others then
                pr_ins_log(v_cod_persona, 'CAM_OFICINA-Error al insertar ge_tra_cli_oficial',1, substr(sqlerrm,1,148));
       END ;

       Begin
          update ge_clientes
            set cod_usu_oficial = reg.cod_usu_ofi_des, 
                cod_oficina = reg.cod_ofi_destino
           where cod_persona = v_cod_persona;
        exception
           when others then
             pr_ins_log(v_cod_persona, 'CAM_OFICINA-Error al modificar ge_clientes',2, substr(sqlerrm,1,148));
        end;
        
        for ctas in c_ctas(v_cod_persona) loop
           Begin
                update ge_cta_clientes g
                      set g.cod_oficina = reg.cod_ofi_destino
                    where g.nro_cuenta = ctas.nro_cuenta 
                      and g.cod_persona = v_cod_persona
                      and g.relacion = 'P' ;
                
                if ctas.cod_modalidad = 31 then -- Ahorro
                    update ah_cta_vistas v
                      set v.cod_oficina = reg.cod_ofi_destino
                    where v.nro_cuenta = ctas.nro_cuenta ;
                end if;

                if ctas.cod_modalidad = 41 then -- Cta Cte
                    update cc_cta_corrientes v
                      set v.cod_oficina = reg.cod_ofi_destino
                    where v.nro_cuenta = ctas.nro_cuenta ;
                end if;

                if ctas.cod_modalidad = 33 then  -- CDA
                    update ah_cta_certificados c
                      set c.cod_oficina = reg.cod_ofi_destino
                    where c.nro_cuenta = ctas.nro_cuenta ;
                end if;

                if ctas.cod_modulo = 6 then -- Prestamos
                    update pr_cta_prestamos p
                      set p.cod_oficina = reg.cod_ofi_destino
                    where p.nro_cuenta = ctas.nro_cuenta ;
                end if;
                
                if ctas.cod_modulo = 5 then -- Tarjetas
                    update ta_cta_tarjetas t
                      set t.cod_oficina = reg.cod_ofi_destino
                    where t.nro_cuenta = ctas.nro_cuenta ;
                end if;
                
                if ctas.cod_modulo = 15 then  -- Cta Vencida
                    update ov_cta_vencidas v
                      set v.cod_oficina = reg.cod_ofi_destino
                    where v.nro_cuenta = ctas.nro_cuenta ;
                end if;
           exception
             when others then
                pr_ins_log(ctas.nro_cuenta , 'CAM_OFICINA-Error al modificar cta',ctas.cod_modalidad, substr(sqlerrm,1,148));
           end;
        end loop;
        
        update GE_CAM_OFI_TMP a 
          set procesado = 'S'
         Where a.cod_persona = v_cod_persona ;
         
        commit ; -- Se comitea por cada registro
    end loop;
   -- sql_util.ejecute_dml('alter trigger TB_GE_CTA_CLIENTES ENABLE',v_men);
EXCEPTION
  WHEN OTHERS THEN
      pr_ins_log(v_cod_persona, 'CAM_OFICINA-Error al cambiar de Oficina',3, substr(sqlerrm,1,148)) ;
end ;
/

