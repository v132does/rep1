CREATE OR REPLACE PROCEDURE IT.PRM_CAN_AUTOMATICA is

/* proceso que cancela en forma automatica las operaciones REPO al vencimiento */
v_lugar varchar2(500); 
rp_docu md_cta_documentos%rowtype;
v_redondeo number(5);
v_mto_desembolsar md_cta_documentos.monto%type;
v_mto_credito md_cta_documentos.monto%type;
v_mto_garantia md_garantias.monto%type;

r_gmovi ge_movimientos%rowtype;
v_fec_actual ge_movimientos.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(10);
v_hora ge_movimientos.hora%type := fug_ini_hora(sysdate,'HH24:MI:SS');
v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
v_transaccion ge_movimientos.cod_transaccion%type := 602;
v_impuesto ge_movimientos.monto%type;
v_cod_moneda ge_movimientos.cod_moneda%type;
v_cod_ofi_origen ge_movimientos.cod_oficina%type;
v_cotizacion ge_movimientos.cotizacion%type;

cursor cuentas is
  select m.nro_cuenta nro_cuenta
     from md_cta_documentos m
    where m.fec_ven_repo = v_fec_actual
      and estado = 'R'
  Union
  Select Distinct b.nro_cta_repo nro_cuenta
    from md_cta_documentos a, md_cuo_instrumentos b
   where a.nro_cuenta = b.nro_cta_repo
     and a.fec_ven_repo = v_fec_actual
     and b.estado = 'R';    -- CNFREINT-1 - Repo Interbancario -- R=Ripeado - RABP-CNF

cursor documentos is
  select nro_cuenta, estado, monto, mto_interes
    from md_cta_documentos
   where nro_cta_padre = rp_docu.nro_cuenta;

/*Inicio*/                                   
begin
  v_lugar := 'Inicio prm_can_automatica';
  v_cod_ofi_origen := FUG_OBT_OFI_USUARIO(user);
  for r1 in cuentas loop
      v_mto_desembolsar := 0;
      v_impuesto := 0;
      v_mto_garantia := 0;
      v_cotizacion := null;
       -- Obtiene datos del documento 
      pam_doc.pr_obt_datos(r1.nro_cuenta, rp_docu);     
      
  	  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 10, rp_docu.cod_modalidad, rp_docu.cod_moneda );
      ------------------------------------ 
      rp_docu.mto_interes     := round((nvl(rp_docu.val_tas_repo,0)*(rp_docu.fec_ven_repo - rp_docu.fec_ini_repo)*nvl(rp_docu.val_bas_repo,0))/36500,v_redondeo);     
      
      if rp_docu.cod_modalidad <> 113 then
         if rp_docu.cod_modalidad in (116,146) then
            --call money plazo
            v_mto_desembolsar := rp_docu.monto - nvl(rp_docu.mto_impuesto, 0);
         else
            v_mto_desembolsar := rp_docu.val_presente; --r_docu.monto - nvl(v_mto_int_adelantado,0);
         end if;
      else
        --crédito tributario
        v_mto_desembolsar := rp_docu.monto - nvl(rp_docu.mto_interes, 0);
      end if;
      begin
        select nvl(sum(monto), 0)
          into v_mto_garantia
          from md_garantias
         where nro_cuenta = rp_docu.nro_cuenta;
      exception
        when others then
          v_mto_garantia := 0;
      end;   
      -- Compra del Documento
      if FUM_OBT_OPE_REPO(rp_docu.cod_modulo,rp_docu.cod_modalidad,'S') = 'N' then
          pam_doc.pr_com_documentos(rp_docu.nro_cuenta,
                                    v_mto_desembolsar,
                                    v_cod_ofi_origen,
                                    v_mto_garantia,
                                    v_fec_actual,
                                    v_hora,
                                    v_nro_secuencia);  
          --Compra de los documentos relacionados
          for doc in documentos loop
              If doc.estado = 'S' then
                 v_nro_secuencia := v_nro_secuencia + 1;
                 --Obtener el monto a compar del documento
                 v_mto_desembolsar := doc.monto - nvl(doc.mto_interes, 0);
                 pam_doc.pr_com_documentos(doc.nro_cuenta,
                                           v_mto_desembolsar,
                                           v_cod_ofi_origen,
                                           0, --mto_garantia
                                           v_fec_actual,
                                           v_hora,
                                           v_nro_secuencia);
              End if;
          end loop;   
      --- CNFREINT-1 Repo Interbancario - RABP-CNF-SETIEMBRE/2015
      elsif FUM_OBT_OPE_REPO(rp_docu.cod_modulo,rp_docu.cod_modalidad,'S') = 'S' then   
          v_nro_secuencia := v_nro_secuencia +1;
          PAM_DOC.PR_ACT_OPE_REPO ( r1.nro_cuenta,    ---Nro. Cta. correspondiente al REPO
                                    'CD',             ---Este valor corresponde a la acción que en este caso es Cancelación de REPO.
                                    v_nro_secuencia,  ---Nro. de secuencia utilizado para insertar datos en ge_movimientos
                                    v_hora);          ---Hora utilizado para insertar datos en ge_movimientos
      end if;    
      
      
    --- --- CNFREINT-1 Repo Interbancario - RABP-CNF-10/2015: Si es Repo no debe generar movimiento desde aca ---
    if FUM_OBT_OPE_REPO(rp_docu.cod_modulo,rp_docu.cod_modalidad,'S') = 'N' then -- CNFREINT-104 --                      
      
      --- Verificar cotizacion
      if rp_docu.cod_moneda <> pag_gen.fu_obt_mon_local then
         v_lugar      := 'pag_gen.fu_obt_cotizacion';
         v_cotizacion := fug_obt_cotizacion(rp_docu.cod_moneda,v_fec_actual);
      end if; 
      
      v_lugar := 'Formas de pago';                              
      if rp_docu.for_pago = 'C' then ---Credito en Cta.
         pag_cta.pr_obt_cuenta(rp_docu.nro_ref_credito);
      elsif rp_docu.for_pago = 'R' then   --Credito en Cta. Contable
         v_lugar := 'Obtiene Mon. Rub.Contable';
         begin
            select cod_moneda
              into v_cod_moneda
              from cb_rubros
             where cod_rubro = rp_docu.nro_ref_credito
               and imputable = 'S';
         exception
	          when no_data_found then
              raise_application_error(-20000,v_lugar||'-'||pag_cta.fu_obt_msj_error());
         end;           
       End if;
-- 
      v_mto_credito := rp_docu.val_bas_repo + nvl(rp_docu.mto_interes,0);
      r_gmovi.cod_sit_contable := rp_docu.cod_sit_contable;
        
      if rp_docu.nro_ref_credito is not null and rp_docu.for_pago = 'C' then 	---Credito en Cta.
         v_lugar := 'prg_ver_cob_cargos';
         v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;	
         --calcula impuesto si corresponde y genera movimiento
         prg_ver_cob_cargos(rp_docu.nro_ref_credito,
                            rp_docu.nro_cuenta,
                            rp_docu.cod_modulo,
                            rp_docu.cod_modalidad,
                            v_cod_ofi_origen,
                            pag_cta.g_ctas.cod_moneda,
                            abs(v_mto_credito),
                            'Compra Documento ' || rp_docu.nro_cuenta,
                            null,--nro_documento
                            v_fec_actual,
                            v_hora,
                            v_impuesto,
                            v_nro_secuencia,
                            'S',-- procesar si
                            v_cotizacion); 

         -- Actualiza la Cuenta Crédito / Destino
         v_lugar := 'pag_cta.pr_act_operacion';
         if nvl(v_impuesto,0) <> 0 then 
            v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
         end if;
         pag_cta.pr_act_operacion( rp_docu.nro_ref_credito,
                                   v_hora,---------------------------- HORA
                                   'C',
                                   pag_cta.g_ctas.cod_moneda,------- Moneda de la Operación
                                   v_mto_credito - nvl(v_impuesto, 0),
                                   101,----------------------------- COD_TRA_PADRE (Desembolso de Préstamo)
                                   v_transaccion,
                                   rp_docu.nro_cuenta,
                                   v_cotizacion,-------------------- COTIZACION
                                   v_cod_ofi_origen,---------------- cod_ofi_origen
                                   rp_docu.cod_modulo,-------------- cod_mod_padre
                                   rp_docu.cod_modalidad,----------- cod_mad_padre
                                   null,---------------------------- cod_tasa
                                   null,---------------------------- val_tasa
                                   'Compra Documento ' ||rp_docu.nro_cuenta,
                                   'S',----------------------------- emi_aviso
                                   v_nro_secuencia,
                                   v_fec_actual);
    				
         if pag_cta.fu_obt_cod_error() <> 0 then
            raise_application_error(-20000,v_lugar||'-'||pag_cta.fu_obt_msj_error());
         end if; 
       elsif rp_docu.nro_ref_credito is not null and rp_docu.for_pago = 'R' then --Credito en Cta. Contable
          v_lugar := 'pag_gen.pr_ins_ge_movimiento';
          v_nro_secuencia         := v_nro_secuencia + 1;
                        
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fec_actual;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_modulo      := rp_docu.cod_modulo;
          r_gmovi.cod_modalidad   := rp_docu.cod_modalidad;
          r_gmovi.cod_oficina     := nvl(rp_docu.cod_ofi_credito,v_cod_ofi_origen);
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.fec_valor       := v_fec_actual;
          r_gmovi.cod_tra_padre   := 101;
          r_gmovi.cod_mod_padre   := rp_docu.cod_modulo;
          r_gmovi.cod_mad_padre   := rp_docu.cod_modalidad;
          r_gmovi.cod_transaccion := 741;
          r_gmovi.monto           := v_mto_credito;
          r_gmovi.nro_documento   := rp_docu.nro_cuenta;
          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Compra Documento ' ||rp_docu.nro_cuenta;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.cod_rubro       := rp_docu.nro_ref_credito;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.tip_mov_rubro   := 'C';
          r_gmovi.cotizacion      := v_cotizacion;
          r_gmovi.mto_equ_local   := round(r_gmovi.monto * nvl(v_cotizacion,0));
          pag_gen.pr_ins_ge_movimiento(r_gmovi);           
       end if; 
    end if;
  end loop;  
exception 
   when others then 
        raise_application_error(-20000,v_lugar||'-'||sqlerrm);     
end prm_can_automatica;
/

