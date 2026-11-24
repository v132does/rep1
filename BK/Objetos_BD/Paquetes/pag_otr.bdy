CREATE OR REPLACE PACKAGE BODY IT.pag_otr IS
  procedure pr_obt_val_cuenta(p_nro_cuenta ge_cuentas.nro_cuenta%type,
                              p_cod_modulo out ba_modulos.cod_modulo%type,
                              p_cod_modalidad out ge_modalidades.cod_modalidad%type,
                              p_cod_moneda out ba_monedas.cod_moneda%type,
                              p_cod_error out number) IS
    v_estado ge_cuentas.estado%type;
  begin
    ---Obtiene la Cuenta, y valida si la cuenta es correcta
    p_cod_error := v_reg_correcto;
    pag_cta.pr_obt_cuenta(p_nro_cuenta);

    if pag_cta.fu_obt_cod_error() <> 0 then
       p_cod_error := v_cta_ori_invalido;
    else
       p_cod_modulo := pag_cta.G_CTAS.cod_modulo;
       p_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
       p_cod_moneda := pag_cta.g_ctas.cod_moneda;
       v_estado := pag_cta.g_ctas.estado;
    end if;
    if p_cod_modalidad not in (31,41,42,443) and p_cod_error = v_reg_correcto then
       p_cod_error := v_cta_ori_invalido;
    end if;
    if v_estado in ('C', 'P') and p_cod_error = v_reg_correcto then
       p_cod_error := v_cta_cancelada;
    end if;
  end;

  function fu_val_ord_transferencia_det(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type) return number is
    v_cod_error number := v_reg_correcto;
    v_exi_cab varchar2(1);
  begin
    begin
      select distinct 'S'
        into v_exi_cab
        from ge_dna_ord_transferencias
       where nro_ord_transferencia = p_nro_ord_transferencia;
    exception
      when others then
        v_exi_cab := 'N';
     end;
     if nvl(v_exi_cab, 'N') <> 'S' then
       v_cod_error := v_ord_tra_inexistente;
     end if;

     return v_cod_error;
  end;

  procedure pr_obt_nro_cta_beneficiario (p_cod_banco ge_dna_ord_transferencias_det.cod_banco%type, p_nro_cuenta ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                         p_nro_cta_beneficiario out ge_dna_ord_transferencias_det.nro_cta_beneficiario%type, p_nro_cta_extracto out varchar2) is
    v_cod_bco_bcp ge_bancos.cod_bco_central%type;
  begin
    begin
      select cod_bco_central
        into v_cod_bco_bcp
        from ge_bancos a
        where a.ubicacion = 'L'
        and a.estado = 'A'
        and a.cod_banco = 1;
    exception
      when others then
        v_cod_bco_bcp := 1001;
    end;

    if p_cod_banco = v_cod_bco_bcp then
      begin
         select b.val_minimo NRO_CTA, b.val_maximo CTA_EXTRACTO
           into p_nro_cta_beneficiario, p_nro_cta_extracto
           from ba_cod_referencias b
          where b.dominio = 'SNP_CTA_INT_BCP_HACIENDA'
            and b.abreviatura = 'ADUANA'
            and b.val_maximo = '001-'||p_nro_cuenta;
       exception
         when others then
           p_nro_cta_beneficiario:= null;
           p_nro_cta_extracto := null;
       end;
    else
      begin
        select a.val_minimo  NRO_CUENTA,(a.abreviatura || '-' || a.val_minimo) CTA_EXTRACTO
          into p_nro_cta_beneficiario, p_nro_cta_extracto
          from ba_cod_referencias a, ge_bancos b
         where a.dominio   = 'CTA_CRE_BCO_COB_SER'
           and a.val_maximo  ='ADUANA'
           and a.abreviatura = b.cod_banco
           and b.cod_bco_central = p_cod_banco
           and a.val_minimo = p_nro_cuenta
           and b.ubicacion   = 'L'
           and b.estado      = 'A';
       exception
         when others then
           p_nro_cta_beneficiario:= null;
           p_nro_cta_extracto := null;
       end;
    end if;
	end;
  procedure pr_ins_log_err_ord_tra (p_nro_ord_transferencia in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                    p_nro_cuenta in varchar2,
                                    p_cod_error in number, p_det_error varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_det_error varchar2(4000);
  begin
     if p_det_error is null then
       begin
         select val_maximo
           into v_det_error
           from ba_cod_referencias
          where dominio = 'COD_ERR_ORD_TRA_DNA'
            and val_minimo = p_cod_error;
       exception
         when others then
           v_det_error := null;
       end;
     end if;
     BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; END;
     insert into ge_dna_log_ord_tra(nro_ord_transferencia,fecha, nro_cuenta,cod_error,det_error)
     values (p_nro_ord_transferencia, sysdate, p_nro_cuenta, p_cod_error, nvl(substr(p_det_error,1,4000), v_det_error));
     commit;
  end;

  function fu_gen_ord_transferencia(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                    p_fecha in date,
                                    p_nro_cta_solicitante in ge_dna_ord_transferencias.nro_cta_solicitante%type,
                                    p_detalle     IN TYP_LISTADETALLEORDTRA,
                                    p_firmante    IN TYP_LISTAFIRMANTEORDTRA,
                                    p_dat_xml in ge_dna_ord_transferencias.dat_xml%type) return number is
    v_cod_error ge_dna_log_ord_tra.cod_error%type := v_reg_correcto;
    v_cod_err_tra  ge_dna_log_ord_tra.cod_error%type := v_reg_correcto;
    v_hora ge_dna_ord_transferencias.hora%type;
    v_cod_modulo ge_cuentas.cod_modulo%type;
    v_cod_modalidad ge_cuentas.cod_modalidad%type;
    v_cod_moneda ge_dna_ord_transferencias.cod_moneda%type;
    v_exi_nro_ord_transferencia ge_dna_ord_transferencias.nro_ord_transferencia%type;
  begin
    v_hora := to_char(sysdate, 'HH24:MI:SS');

    begin
      select distinct 'S'
        into v_exi_nro_ord_transferencia
        from ge_dna_ord_transferencias
       where nro_ord_transferencia = p_nro_ord_transferencia;
    exception
      when others then
        v_exi_nro_ord_transferencia := 'N';
    end;

    if nvl(v_exi_nro_ord_transferencia, 'N') = 'S' then
      v_cod_error := v_nro_ord_dup;
    end if;

    if v_cod_error = v_reg_correcto then
       pr_obt_val_cuenta(p_nro_cta_solicitante, v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_error);
    end if;
    IF v_cod_error = v_reg_correcto then
      begin
         insert into ge_dna_ord_transferencias(nro_ord_transferencia,fecha,hora,cod_modulo,cod_modalidad,nro_cta_solicitante,
                                               cod_moneda, dat_xml)
         values(p_nro_ord_transferencia, p_fecha, v_hora, v_cod_modulo, v_cod_modalidad, p_nro_cta_solicitante, v_cod_moneda, p_dat_xml);
      exception
        when others then
          pr_ins_log_err_ord_tra (p_nro_ord_transferencia, p_nro_cta_solicitante, v_otr_error, sqlerrm);
          v_cod_error := v_otr_error;
      end;
      if v_cod_error = v_reg_correcto then
         FOR i in 1..p_detalle.count LOOP
           if v_cod_error = v_reg_correcto then
             v_cod_error := fu_ins_ord_transferencia_det(p_nro_ord_transferencia, p_detalle(i).nro_item, p_detalle(i).nro_cta_beneficiario, p_detalle(i).denominacion, p_detalle(i).cod_banco, p_detalle(i).monto);
           end if;
        END LOOP;
      end if;
      if v_cod_error = v_reg_correcto then
         FOR i in 1..p_firmante.count LOOP
           if v_cod_error = v_reg_correcto then
              v_cod_error := fu_ins_ord_tra_firmantes(p_nro_ord_transferencia, p_firmante(i).nombre);
           end if;
         END LOOP;
      end if;


      if v_cod_error = v_reg_correcto then
         v_cod_err_tra := fu_gen_snp_transferencias(p_nro_ord_transferencia);
      end if;

      if v_cod_err_tra <> v_reg_correcto then
         pr_ins_log_err_ord_tra (p_nro_ord_transferencia, p_nro_cta_solicitante, v_cod_error, 'No se ha registrado la transacción');
      end if;

      if v_cod_error = v_reg_correcto then
         pr_gen_not_ord_tra(p_nro_ord_transferencia);
      end if;
      return v_cod_error;
    else
      pr_ins_log_err_ord_tra (p_nro_ord_transferencia, p_nro_cta_solicitante, v_cod_error, null);
      return v_cod_error;
    end if;
  end;

  function fu_ins_ord_transferencia_det(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                        p_nro_item ge_dna_ord_transferencias_det.nro_item%type,
                                        p_nro_cta_beneficiario in ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                        p_denominacion in ge_dna_ord_transferencias_det.denominacion%type,
                                        p_cod_banco in ge_dna_ord_transferencias_det.cod_banco%type,
                                        p_monto in ge_dna_ord_transferencias_det.monto%type) return number is
     v_nro_cta_beneficiario ge_dna_ord_transferencias_det.nro_cta_beneficiario%type;
     v_nro_cta_extracto ge_dna_ord_transferencias_det.nro_cta_extracto%type;
     v_cod_error ge_dna_log_ord_tra.cod_error%type := v_reg_correcto;
     v_det_error ge_dna_log_ord_tra.det_error%type;
  begin
     pr_obt_nro_cta_beneficiario (p_cod_banco, p_nro_cta_beneficiario,
                                  v_nro_cta_beneficiario, v_nro_cta_extracto);

     if v_nro_cta_beneficiario is null then
        v_cod_error := v_cta_des_invalido;
     end if;

     if v_cod_error = v_reg_correcto then
        v_cod_error := fu_val_ord_transferencia_det(p_nro_ord_transferencia);
     end if;

     begin
       BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; END;
       insert into ge_dna_ord_transferencias_det(nro_ord_transferencia,
                                                 nro_item,
                                                 nro_cta_beneficiario,
                                                 denominacion,
                                                 cod_banco,
                                                 monto,
                                                 estado,
                                                 nro_cta_extracto,
                                                 cod_retorno)
                                         values (p_nro_ord_transferencia,
                                                 p_nro_item,
                                                 v_nro_cta_beneficiario,
                                                 p_denominacion,
                                                 p_cod_banco,
                                                 p_monto,
                                                 'I', -- Ingresado
                                                 v_nro_cta_extracto,
                                                 v_cod_error);
     exception
        when others then
          v_cod_error := v_otr_error;
          v_det_error := substr(sqlerrm,1,4000);
      end;
      if v_cod_error <> v_reg_correcto then
        pr_ins_log_err_ord_tra (p_nro_ord_transferencia, v_nro_cta_beneficiario, v_cod_error, v_det_error);
      end if;

      return v_cod_error;
  end;

  function fu_gen_snp_transferencias (p_nro_ord_transferencia ge_dna_ord_transferencias.nro_ord_transferencia%type) return number is
    cursor c_ord_tra is
      select c.cod_modulo, c.cod_modalidad, c.nro_cta_solicitante, c.cod_moneda, d.cod_banco cod_bco_beneficiario,
             d.nro_cta_beneficiario, d.monto, d.nro_cta_extracto
      from ge_dna_ord_transferencias c, ge_dna_ord_transferencias_det d
      where c.nro_ord_transferencia = p_nro_ord_transferencia
        and c.nro_ord_transferencia = d.nro_ord_transferencia
        and d.estado = 'I';

      v_fec_actual ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(1);
      v_hora ge_movimientos.hora%type;
      v_cod_error ge_dna_log_ord_tra.cod_error%type := v_reg_correcto;
      v_cta_interbancaria  ge_movimientos.nro_cuenta%type;
      v_cod_ente ge_entes.cod_ente%type;
      v_cod_msj_swift ge_snp_transferencias.cod_msj_swift%type;
      v_ind_valor ge_snp_transferencias.ind_valor%type;
      v_cod_tip_operacion varchar2(10);
      v_cod_sub_tip_operacion varchar2(10);
      v_cod_bco_bcp ge_bancos.cod_bco_central%type := 1001;
      v_estado ge_movimientos.estado%type;
      v_cod_persona ge_movimientos.cod_persona%type;
      v_cod_tra_debito ge_transacciones.cod_transaccion%type;
      v_nro_secuencia ge_movimientos.nro_secuencia%type;
      v_nro_cta_extracto ge_movimientos.concepto%type;
      v_procesa varchar2(1);
      v_nvo_estado ge_cuentas.estado%type;
      v_sal_disponible cc_cta_corrientes.sal_total%type;
      v_cod_tra_hijo       ge_transacciones.cod_transaccion%type;
      v_cod_mod_padre      ge_transacciones.cod_modulo%type;
      v_cod_mad_padre      ge_transacciones.cod_modalidad%type;
	    v_tra_padre  ge_transacciones.cod_transaccion%TYPE := pas_snp.fu_obt_cod_tra_padre;
      v_cod_modulo ba_modulos.cod_modulo%type;
      v_cod_modalidad ge_modalidades.cod_modalidad%type;
      v_nro_referencia  ge_snp_transferencias.nro_referencia%type  := null;
      v_cod_programa    varchar2(50) := null;
      v_nro_ref_externa ge_snp_transferencias.nro_ref_externa%type := null;
      v_msj_swift ge_snp_transferencias.msj_swift%type;
      v_nro_cta_pte_solicitante ge_snp_transferencias.msj_swift%type;
      v_cod_swi_pte_solicitante ge_bancos.cod_swift%type;
      v_cod_per_beneficiario ba_personas.cod_persona%type;
      v_nom_beneficiario ba_personas.nom_completo%type;
      v_cod_per_ente ba_personas.cod_persona%type;
      v_dir_beneficiario ge_snp_transferencias.dir_beneficiario%type;
      v_nro_doc_beneficiario ge_snp_transferencias.nro_doc_beneficiario%type;
      v_cod_tip_doc_beneficiario ge_snp_transferencias.cod_tip_doc_beneficiario%type;
      v_per_pte_beneficiario varchar2(10);
      v_cod_per_banco ge_bancos.cod_persona%type;
      v_nro_cta_pte_beneficiario ge_snp_transferencias.nro_cta_pte_beneficiario%type;
      v_cod_banco ge_bancos.cod_banco%type;
      v_cod_swi_pte_beneficiario ge_snp_transferencias.cod_swi_pte_beneficiario%type;
      v_tip_cargo ge_snp_transferencias.tip_cargo%type;
  begin
    pae_cnf.g_programa := 'AMTRCSER';
    begin
      select r.cod_ente, cod_persona -- cod ente aduana
        into v_cod_ente, v_cod_per_ente
        from ge_entes e, ge_par_entes r
       where e.cod_ente = r.cod_ente
         and e.tipo = 'TH'
         and r.parametro = 'SNP_UTI_AMTRCSER'
         and r.val_parametro = 'S';

    end;
    v_per_pte_beneficiario := substr( fug_obt_parentes( v_cod_ente, 'SNP_PER_PTE_BENEFICIARIO' ), 1, 10 );
    v_cod_tra_debito := substr( nvl( fug_obt_parentes( v_cod_ente, 'SNP_COD_TRA_DEBITO' ),503),1,4);
    v_cod_msj_swift := nvl(fug_obt_parentes (v_cod_ente,'SNP_COD_MT'),103);
    v_cod_tip_operacion := nvl(fug_obt_parentes (v_cod_ente,'SNP_MT_TIPO'), '001');

    for c in c_ord_tra loop
      v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
      pas_snp.pr_ini_variables;

      pag_cta.pr_set_cod_rubro(NULL,NULL);
      pag_cta.pr_set_nro_documento2(NULL);
      pag_cta.pr_set_referencia(NULL);
      v_nro_secuencia := 0;

      v_cod_persona := fug_obt_cli_principal(c.nro_cta_solicitante);

      if pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_ban_participante( pas_snp.fu_obt_cod_swi_participante( fug_obt_per_entidad ), c.cod_moneda), 'C' ) is null and
           pas_snp.fu_obt_cod_error <> 0 then
           v_cod_error := v_cta_des_invalido;
           pr_ins_log_err_ord_tra (p_nro_ord_transferencia, c.nro_cta_solicitante, v_cod_error, pas_snp.fu_obt_cod_error||' - '|| pas_snp.fu_obt_msj_error);
      end if;

      if v_cod_error = v_reg_correcto then

        if c.cod_bco_beneficiario = v_cod_bco_bcp then
           v_cod_sub_tip_operacion := nvl(fug_obt_parentes (v_cod_ente,'SNP_MT_SUB_TIPO'),'003');
        else
           v_cod_sub_tip_operacion := '002';
        end if;

        v_nro_cta_extracto := c.nro_cta_extracto;

        if v_cod_msj_swift = 103 then
          v_ind_valor := 'S';
        elsif v_cod_msj_swift = 102 then
          v_ind_valor := 'N';
        end if;

        if pas_snp.fu_obt_est_horario(v_cod_msj_swift,
                                      v_cod_tip_operacion,
                                      v_cod_sub_tip_operacion) <> 'A'
        then
           if pas_snp.fu_obt_cod_error <> 0 then
             v_cod_error := v_otr_error;
             pr_ins_log_err_ord_tra (p_nro_ord_transferencia, c.nro_cta_solicitante, v_cod_error, pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error);
      	   end if;
        end if;


        v_cta_interbancaria := pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_ban_participante( pas_snp.fu_obt_cod_swi_participante( fug_obt_per_entidad ),
                                                                                               c.cod_moneda), 'C');

        pag_cta.pr_set_nro_documento2(nvl(fug_obt_parentes (v_cod_ente,'SNP_COD_MT'),103)||
                                          v_cod_tip_operacion||
                                          v_cod_sub_tip_operacion);

        v_estado := fug_obt_est_mov_confirmado(c.monto,c.cod_moneda,4,455,303,
																					     'X', c.nro_cta_solicitante,v_cod_persona);

        pag_cta.pr_set_est_movimiento(v_estado);


        -- Registra la operación de DÉBITO
        if v_cod_error = v_reg_correcto then
          pag_cta.PR_VER_OPERACION(c.nro_cta_solicitante,303,4,455,'D',
                                   c.cod_moneda,c.monto,1,
                                   v_cod_modulo, v_cod_modalidad, v_nvo_estado,
                                   v_sal_disponible,v_procesa,v_cod_tra_debito);

          if v_procesa = 'N' then
             v_cod_error := v_otr_error;
             pr_ins_log_err_ord_tra (p_nro_ord_transferencia, c.nro_cta_solicitante, v_cod_error, substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000));
          end if;

          if nvl(v_cod_error,'000') = v_reg_correcto then
            pag_cta.pr_act_operacion( c.nro_cta_solicitante,
                                      v_hora,                    -- HORA
                                      'D',
                                      c.cod_moneda,
                                      c.monto,
                                      303,                        -- COD_TRA_PADRE DE TRANSFERENCIA INTERBANCARIA (SNP)
                                      v_cod_tra_debito, -- COD_TRA_HIJO
                                      NULL,
                                      NULL,                       -- COTIZACION
                                      1,      -- cod_ofi_origen ver con Milton
                                      4,                          -- :cuentas.wk_cod_modulo,    --COD_MOD_PADRE
                                      455,                        -- :cuentas.sc_cod_modalidad, --COD_MAD_PADRE
                                      null,                       -- cod_tasa
                                      null,                       -- val_tasa
                                      v_nro_cta_extracto, -- concepto
                                      'S',                         -- emi_aviso
                                      v_nro_secuencia,
                                      v_fec_actual);
            if pag_cta.fu_obt_cod_error() <> 0 then
               v_cod_error := v_otr_error;
               pr_ins_log_err_ord_tra (p_nro_ord_transferencia, c.nro_cta_solicitante, v_cod_error, substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000));
            else
               update ge_movimientos x
		              set x.cod_banco   = c.cod_bco_beneficiario,
		                  x.referencia  = c.nro_cta_beneficiario
		            where x.fecha       = v_fec_actual
		      	      and x.cod_tra_padre = 303
		              and x.cod_modalidad = 455
		              and x.hora        = v_hora
		              and x.cod_usuario = user;

               -- Asigna el Rubro para SNP
	             pag_cta.pr_set_cod_rubro( pac_che.fu_obt_rub_cta_ban( v_cta_interbancaria ), 'C' );

	             pas_snp.pr_obt_par_mensajes(v_cod_msj_swift,
	                                         v_cod_tip_operacion,
	                                         v_cod_sub_tip_operacion,
	                                         'E',
	                                         v_cod_mod_padre,
	                                         v_cod_mad_padre,
                                           v_cod_tra_debito
	                                        -- v_cod_tra_hijo,
	                                       --  v_tra_padre -- CNFPRSIP-217 - Pago a Proveedores - Nueva Transaccion
	                                         );

               pag_cta.PR_VER_OPERACION(v_cta_interbancaria,303,v_cod_mod_padre,v_cod_mad_padre,'C',
                                        c.cod_moneda,c.monto,1,
                                        v_cod_modulo, v_cod_modalidad, v_nvo_estado,
                                        v_sal_disponible,v_procesa,v_cod_tra_hijo);

               if v_procesa = 'N' then
                  v_cod_error := v_otr_error;
                  pr_ins_log_err_ord_tra (p_nro_ord_transferencia, v_cta_interbancaria, v_cod_error, substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000));
               else
                 -- Registra la operación de CREDITO
                 pag_cta.pr_act_operacion( v_cta_interbancaria,
                                           v_hora,                   -- HORA
                                           'C',                      -- Debito por que es Cuenta Corresponsal
                                           c.cod_moneda,   -- Moneda de la Operación
                                           c.monto,
                                           303,                      -- COD_TRA_PADRE (303)
                                           v_cod_tra_hijo,           -- COD_TRA_HIJO (190)
                                           null,
                                           null,                     -- COTIZACION
                                           1,    -- cod_ofi_origen
                                           v_cod_mod_padre,          -- cod_mod_padre
                                           v_cod_mad_padre,          -- cod_mad_padre
                                           null,                     -- cod_tasa
                                           null,                     -- val_tasa
                                           v_nro_cta_extracto,
                                           'S',                      -- emi_aviso
                                           v_nro_secuencia,
                                           v_fec_actual
                                          );

                 if pag_cta.fu_obt_cod_error() <> 0 then
                   v_cod_error := v_otr_error;
                   pr_ins_log_err_ord_tra (p_nro_ord_transferencia, v_cta_interbancaria, v_cod_error, substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000));
                 else
                   	update ge_movimientos x
		                   set x.concepto		= v_nro_cta_extracto
		                 where x.fecha       = v_fec_actual
		                   and x.cod_tra_padre = 303
		                   and x.cod_mad_padre = 455
		                   and x.cod_modalidad <> 455
		                   and x.hora        = v_hora
		                   and x.cod_usuario = user
		                   and x.nro_secuencia in (1,2);
                   -- se genera la transferencia
                   pas_snp.pr_gen_mov_snp( p_hora            => v_hora,
   												                 p_fecha           => v_fec_actual,
                                           p_cod_usuario     => user,
                                           p_gen_workflow		 => 'S',
                                           p_origen          => 'I',
                                           p_plataforma      => 'X',
                                           p_nro_ref_externa => v_nro_ref_externa,
                                           p_ind_enviado     => 'S',
                                           p_cod_programa    => v_cod_programa,
                                           p_nro_referencia  => v_nro_referencia
                                          -- p_cod_tra_padre   => v_tra_padre   -- MDPRMTMP-1 -- 10/2016 --
                         );
                   --:cuentas.sc_nro_documento := :global.wk_nro_referencia;
                   pag_cta.pr_set_est_movimiento('N');

                   v_cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante( fug_obt_per_entidad );
                   v_nro_cta_pte_solicitante := pas_snp.fu_obt_cta_ban_participante( v_cod_swi_pte_solicitante,c.cod_moneda );
                   if c.cod_bco_beneficiario = v_cod_bco_bcp then
                      v_cod_per_beneficiario := v_cod_persona;
                      v_nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante( pas_snp.fu_obt_cod_swi_participante( v_per_pte_beneficiario ),c.cod_moneda);
                   else
                      v_cod_per_beneficiario := v_cod_per_ente;

                      select a.cod_banco, a.cod_persona
                        into v_cod_banco, v_cod_per_banco
                        from ge_bancos a
                       where a.ubicacion = 'L'
                         and a.estado = 'A'
                         and a.cod_bco_central = c.cod_bco_beneficiario;

                      v_nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante( pas_snp.fu_obt_cod_swi_participante( v_cod_per_banco), c.cod_moneda);

                   end if;
                   v_nom_beneficiario := fue_obt_nom_persona(v_cod_per_beneficiario);
                   v_dir_beneficiario := fue_obt_dir_principa(v_cod_per_beneficiario);
                   v_nro_doc_beneficiario := pas_snp.fu_obt_nro_doc_persona(v_cod_per_beneficiario);
	                 v_cod_tip_doc_beneficiario := fue_obt_doc_principal(v_cod_per_beneficiario);
                   v_cod_swi_pte_beneficiario := pas_snp.fu_obt_cod_swi_participante( v_per_pte_beneficiario );

                   begin
                     select t.val_minimo
                       into v_tip_cargo
                       from ba_cod_referencias t
                      where t.dominio = 'TIP_CAR_SWIFT'
                        and t.val_maximo = 'DEFAULT';
                   exception
                     when others then
                        v_tip_cargo := 'OUR';
                   end;

                   update ge_snp_transferencias
                      set nro_cta_pte_solicitante = v_nro_cta_pte_solicitante,
                          cod_per_beneficiario = v_cod_per_beneficiario,
                          nom_beneficiario = v_nom_beneficiario,
                          dir_beneficiario = v_dir_beneficiario,
                          cod_tip_doc_beneficiario = v_cod_tip_doc_beneficiario,
                          nro_doc_beneficiario = v_nro_doc_beneficiario,
                          nro_cta_beneficiario = c.nro_cta_beneficiario,
                          nro_cta_pte_beneficiario = v_nro_cta_pte_beneficiario,
                          cod_swi_pte_beneficiario = v_cod_swi_pte_beneficiario,
                          tip_cargo = v_tip_cargo,
                          tip_mensaje ='CRED'
                    where nro_referencia = v_nro_referencia;

                    v_msj_swift := pas_snp.fu_obt_msj_mt103(v_nro_referencia, 'S');

                    update ge_snp_transferencias
                       set msj_swift = v_msj_swift
                     where nro_referencia = v_nro_referencia;
                 end if;
              end if;


            end if;
          end if;
        end if;
      end if;
      if v_cod_error = v_reg_correcto then
         pr_act_est_ord_transferencia(p_nro_ord_transferencia, c.nro_cta_beneficiario, 'E');
      	 pr_act_nro_referencia(p_nro_ord_transferencia, c.nro_cta_beneficiario, v_nro_referencia);
      else
         pr_act_est_ord_transferencia(p_nro_ord_transferencia, c.nro_cta_beneficiario, 'I');
      end if;
    end loop;
    return v_cod_error;
  end;

  function fu_ins_ord_tra_firmantes (p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                      p_nombre in ge_dna_ord_tra_firmantes.nombre%type) return number is
    v_cod_error ge_dna_log_ord_tra.cod_error%type := v_reg_correcto;
    v_det_error ge_dna_log_ord_tra.det_error%type;
  begin
    v_cod_error := fu_val_ord_transferencia_det(p_nro_ord_transferencia);
    begin
      BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; END;
      insert into ge_dna_ord_tra_firmantes(nro_ord_transferencia,cod_fir_ord_tra,nombre)
      values(p_nro_ord_transferencia, s_cod_fir_ord_tra.nextval, p_nombre);
    exception
      when others then
        v_cod_error := v_otr_error;
        v_det_error := substr('Firmante: '||p_nombre||'. '||sqlerrm,1,4000);
    end;

    if v_cod_error <> v_reg_correcto then
       pr_ins_log_err_ord_tra (p_nro_ord_transferencia, null, v_cod_error, v_det_error);
    end if;

    return v_cod_error;
  end;

  procedure pr_act_est_ord_transferencia(p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                        p_nro_cta_beneficiario in ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                        p_estado in ge_dna_ord_transferencias_det.estado%type) is
  begin
    begin
      BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; END;
      update ge_dna_ord_transferencias_det
         set estado = p_estado
       where nro_ord_transferencia = p_nro_ord_transferencia
         and nro_cta_beneficiario = p_nro_cta_beneficiario;
    exception
      when others then
        raise_application_error(-20000, 'Error al actualizar el estado de la Orden de Transferencia. '||sqlerrm);
    end;
  end;

  procedure pr_act_nro_referencia (p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                  p_nro_cta_beneficiario in ge_dna_ord_transferencias_det.nro_cta_beneficiario%type,
                                  p_nro_referencia in ge_dna_ord_transferencias_det.nro_referencia%type) is
  begin
    begin
      BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; END;
      update ge_dna_ord_transferencias_det
         set nro_referencia = p_nro_referencia
       where nro_ord_transferencia = p_nro_ord_transferencia
         and nro_cta_beneficiario = p_nro_cta_beneficiario;
    exception
      when others then
        raise_application_error(-20001, 'Error al actualizar el número de referencia de la Orden de Transferencia. '||sqlerrm);
    end;
  end;
  procedure pr_gen_not_ord_tra (p_nro_ord_transferencia  in ge_dna_ord_transferencias.nro_ord_transferencia%type)
  is
    v_dir_mail        ge_par_dinamicos.val_parametro%type;
    c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');
    v_texto           varchar2(32000);
    -- Variables para mail
    v_asunto          VARCHAR2(2000);
    v_mje_mail        LONG;
    /* -- Variables coneccion*/
    v_membrete LONG := fug_gen_template('M')|| chr(10);
    V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
    V_PIE      LONG := chr(10) ||fug_gen_template('P');
    v_nro_cta_beneficiario ge_dna_ord_transferencias_det.nro_cta_beneficiario%type;
    v_mto_transferencia ge_dna_ord_transferencias_det.monto%type;
    v_cod_moneda ba_monedas.cod_moneda%type;
    v_des_estado ba_cod_referencias.significado%type;
    v_det_mail LONG := '';
    cursor cu_transferencias is
      select d.nro_cta_beneficiario, d.cod_banco, d.denominacion, d.monto, d.nro_referencia, d.cod_retorno
        from ge_dna_ord_transferencias_det d
       where d.nro_ord_transferencia = p_nro_ord_transferencia;

    FUNCTION fu_eli_acentos
     (
        p_cadena VARCHAR2
     ) RETURN VARCHAR2 IS
        v_cadena VARCHAR2(4000);
     BEGIN
        IF p_cadena IS NOT NULL THEN
           v_cadena := translate(p_cadena,
                    'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                    'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
           v_cadena := translate(v_cadena,
                    'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                    'aeiouAEIOUAaDO     a  o  y yAa                           ');
           v_cadena := translate(v_cadena,
                    '''',
                    '  ');
        END IF;
        RETURN(v_cadena);
     END;

    Function fu_val_correo(p_mail VARCHAR2) RETURN VARCHAR2 IS
        v_mail         VARCHAR2(319) := lower(p_mail);
        v_nom_usuario  VARCHAR2(64);
        v_nom_dominio  VARCHAR2(254);
        v_caracter     VARCHAR2(1);
        v_posicion     NUMBER(3);
        v_car_invalido NUMBER(3);
        v_con_caracter NUMBER(3) := 0;
        --
        v_pos_coma     NUMBER(3);
        v_pos_punto    NUMBER(3);
     BEGIN
        --- Identificar el primer correo
        v_pos_punto    := instr(v_mail, ';'); -- hasta el punto y coma
        v_pos_coma     := instr(v_mail, ','); -- hasta la coma
        IF v_pos_punto = 0 and v_pos_coma = 0 THEN
           v_posicion := length(v_mail);
        ELSIF v_pos_coma = 0 THEN
           v_posicion := v_pos_punto - 1;
        ELSIF v_pos_punto = 0 THEN
           v_posicion := v_pos_coma - 1;
        ELSIF v_pos_coma > v_pos_punto THEN
           v_posicion := v_pos_punto - 1;
        ELSIF v_pos_punto > v_pos_coma THEN
           v_posicion := v_pos_coma - 1;
        ELSE -- Contiene solo 1 correo
           v_posicion := length(v_mail);
        END IF;
        v_mail := substr(v_mail, 1, v_posicion);
        --
        v_posicion    := instr(v_mail, '@');
        v_nom_usuario := substr(v_mail, 1, instr(v_mail, '@') - 1);
        v_nom_dominio := substr(v_mail, instr(v_mail, '@') + 1);
        ---
        /*
        || Dominios Genéricos
        || ==================
        || .com .net .org
        || .mil .gov .edu .int .coop
        || .info .biz
        || .mobi
        */
        IF instr(v_nom_dominio,'.com',1) > 0 OR
           instr(v_nom_dominio,'.net',1) > 0 OR
           instr(v_nom_dominio,'.org',1) > 0 OR
           instr(v_nom_dominio,'.mil',1) > 0 OR
           instr(v_nom_dominio,'.gov',1) > 0 OR
           instr(v_nom_dominio,'.edu',1) > 0 OR
           instr(v_nom_dominio,'.int',1) > 0 OR
           instr(v_nom_dominio,'.biz',1) > 0 OR
           instr(v_nom_dominio,'.coop',1) > 0 OR
           instr(v_nom_dominio,'.info',1) > 0 OR
           instr(v_nom_dominio,'.mobi',1) > 0 THEN
           null;
        ELSE
           return null;
        END IF;
        v_mail := fu_eli_acentos(v_mail);
        ---
        FOR i IN 1 .. length(v_mail) LOOP
           v_caracter := substr(v_mail, i, 1);
           IF v_caracter = '@' THEN
              v_con_caracter := v_con_caracter + 1;
           END IF;
        END LOOP;
        ---
        IF v_posicion <= 1 OR
           v_posicion = length(v_mail) OR
           v_con_caracter > 1 THEN
           return null;
        ELSIF substr(v_nom_usuario, 1, 1) = '.' OR
              substr(v_nom_usuario, length(v_nom_usuario), 1) = '.' THEN
           return null;
        ELSIF substr(v_nom_dominio, 1, 1) = '.' OR
              substr(v_nom_dominio, length(v_nom_dominio), 1) = '.' OR
              instr(v_nom_dominio, '.') = 0 THEN
           return null;
        ELSIF v_car_invalido > 0 THEN
           return null;
        ELSIF instr(v_mail, '..') > 0 THEN
           return null;
        ELSIF length(v_nom_usuario) > 64 THEN
           return null;
        ELSIF length(v_nom_dominio) > 255 THEN
           return null;
        END IF;
        RETURN v_mail;
     END;
  begin
------
    v_dir_mail := fug_obt_pardinamico('FDI_COR_NOT_ORD_TRA');

    --Seteos iniciales
    v_dir_mail        := trim(v_dir_mail);

    if v_dir_mail is null then
       --Si esta nulo se toma se guarda error
       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
       values (c_dir_mail, v_dir_mail,'NOTIFICACION ORDEN DE TRANSFERENCIA', 'No tiene parametrizado direccion de mail', sysdate, user);
    end if;
    --validacion bancard
    begin
      select c.nro_cta_solicitante, sum(monto), cod_moneda
        into v_nro_cta_beneficiario, v_mto_transferencia, v_cod_moneda
        from ge_dna_ord_transferencias c, ge_dna_ord_transferencias_det d
       Where c.nro_ord_transferencia = p_nro_ord_transferencia
         and c.nro_ord_transferencia = d.nro_ord_transferencia
        group by c.nro_cta_solicitante, cod_moneda;
    exception
      when others then
        v_nro_cta_beneficiario := null;
        v_mto_transferencia := 0;
    end;

    if nvl(v_mto_transferencia,0) = 0 then
       --Si esta nulo se toma se guarda error
       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
       values (c_dir_mail, v_dir_mail,'NOTIFICACION ORDEN DE TRANSFERENCIA', 'No se encuentra el detalle de la orden Nro: '||p_nro_ord_transferencia, sysdate, user);
    end if;

    if nvl(v_mto_transferencia,0) <> 0 then
      begin
        v_texto := '<br><br>
                    <br><br>
                        Estimado,
                    <br><br>
                        Se notifica que recibida la Orden de Transferencia Nro. ' || p_nro_ord_transferencia ||' de la cuenta Nro '|| v_nro_cta_beneficiario ||' por el monto '||ltrim(rtrim(to_char(v_mto_transferencia, '999G999G999G999G999')))||' '||v_cod_moneda||'.'||
                    '<br> A continuación se detalla las transferencias procesadas:
                    <br><br>
                     <table cellspacing="0"
                          cellpadding="7"
                          border="4">
                    <tr>
                          <td width="80%" bgcolor="B0C4DE"> <b>Nro. Cuenta</b></td>
                          <td width="80%" bgcolor="B0C4DE"> <b>Banco</b></td>
                          <td width="80%" bgcolor="B0C4DE"> <b>Denominación</b></td>
                          <td width="80%" bgcolor="B0C4DE"> <b>Importe</b></td>
                          <td width="80%" bgcolor="B0C4DE"> <b>Nro Referencia</b></td>
                          <td width="80%" bgcolor="B0C4DE"> <b>Cod. Retorno</b></td>
                          <td width="80%" bgcolor="B0C4DE"> <b>Descripción</b></td>
                     </tr>';

       FOR t IN cu_transferencias LOOP
          begin
            select significado
              into v_des_estado
              from ba_cod_referencias
             where dominio = 'COD_ERR_ORD_TRA_DNA'
               and val_minimo = t.cod_retorno;
          exception
            when others then
               v_des_estado := 'No definido.';
          end;
          v_det_mail := v_det_mail || '<tr>
                                      <td width="180%" bgcolor="FFFFFF">'||t.nro_cta_beneficiario||'</td>
                                      <td width="180%" bgcolor="FFFFFF">'||t.cod_banco||'</td>
                                      <td width="180%" bgcolor="FFFFFF">'||t.denominacion||'</td>
                                      <td width="180%" bgcolor="FFFFFF">'||t.monto||'</td>
                                      <td width="180%" bgcolor="FFFFFF">'||t.nro_referencia||'</td>
                                      <td width="180%" bgcolor="FFFFFF">'||t.cod_retorno||'</td>
                                      <td width="180%" bgcolor="FFFFFF">'||v_des_estado||'</td>
                                      </tr> ';
          EXIT WHEN cu_transferencias%NOTFOUND;
        END LOOP;
      end;

      v_asunto   := 'NOTIFICACION: RECEPCION ORDEN DE TRANSFERENCIA';

      v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||v_det_mail||'</table>
                             </i><br><br>
                             Atentamente.
                             <br><br>
                             <p align="center"><i><b>Banco GNB S.A.(en Proceso de Fusi&oacute;n por Absorci&oacute;n)</b></i></p>
                             <br><br>
                             <br><br>'||
                             chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

      if v_dir_mail  is not null then
         --********** Logica para envio por email de los archivos ******************
         Begin
           /*v_conn     := it_mail.begin_mail(c_dir_mail,
                                            v_dir_mail,
                                            v_asunto,
                                            IT_MAIL.MULTIPART_MIME_TYPE);

           it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
           it_mail.end_mail(v_conn);*/

           insert into ge_notificaciones(NRO_NOTIFICACION,FECHA,ENV_POR,ENV_PARA,
                                         ASUNTO,DETALLE,COD_USUARIO,
                                         TIPO,FORMATO,Tip_Notificacion)
                                  values(s_nro_notificacion.nextval, trunc(sysdate),c_dir_mail,v_dir_mail,
                                         'NOTIFICACION: RECEPCION ORDEN DE TRANSFERENCIA',v_mje_mail,
                                         user,'NOTEXTDNA','text/html',2);

          EXCEPTION
             when others then
                insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                            values (c_dir_mail, v_dir_mail, v_asunto, v_texto, sysdate, user);
          END;
       end if;
    END IF;
    --*********************************************************************************************************
  EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20000,'PRG_GEN_ARC_CON_SET '||sqlerrm);
  end;
  function fu_obt_bancos return typ_listabancos is
     r_bancos        typ_detalleBanco;
     r_banco_det     TYP_LISTADETALLEBANCOS:= TYP_LISTADETALLEBANCOS();
     r_bancos2        typ_bancos ;
     r_lista_bancos  typ_listabancos := typ_listabancos();
     CURSOR c_bancos IS
      SELECT b.cod_bco_central, b.descripcion
        FROM ge_bancos b
       WHERE b.ubicacion = 'L'
         and b.estado = 'A';
  begin
   
    FOR i IN c_bancos LOOP
      r_bancos:= typ_detalleBanco(null,i.descripcion,null,i.cod_bco_central,NULL,NULL,NULL);
      r_banco_det.extend;
      r_banco_det(r_banco_det.count) := r_bancos;
    END LOOP;
    r_bancos2 := typ_bancos(NULL, NULL,NULL,NULL, r_banco_det);
    r_lista_bancos.extend;
    r_lista_bancos(r_lista_bancos.count) := r_bancos2;
   
    RETURN(r_lista_bancos);
  end;

  procedure pr_obt_dat_transferencia (p_nro_ord_transferencia ge_dna_ord_transferencias.nro_ord_transferencia%type,
                                    p_cod_res_cab out ge_dna_ord_transferencias_det.cod_banco%type, p_des_res_cab out varchar2,
                                    p_item out typ_listaitemordtra)  is
     r_lista_item    typ_listaitemordtra := typ_listaitemordtra();
     r_item          typ_itemordtra := typ_itemordtra;
     v_exi_transferencia varchar2(1) := 'N';
     v_can_item          number;
     v_can_enviados      number;
     v_can_ingresados    number;
     CURSOR c_item IS
      SELECT d.nro_item, d.nro_cta_beneficiario, d.estado, d.cod_retorno
        from ge_dna_ord_transferencias_det d
       WHERE nro_ord_transferencia = p_nro_ord_transferencia;
  begin
    begin
      select distinct 'S'
        into v_exi_transferencia
        from ge_dna_ord_transferencias
       where nro_ord_transferencia = p_nro_ord_transferencia;
    exception
      when others then
        v_exi_transferencia := 'N';
    end;

    if v_exi_transferencia = 'N' then
       p_cod_res_cab := v_ord_tra_inexistente;
    END if;

    if v_exi_transferencia = 'S' then
      begin
        select count(*), sum(decode(estado, 'I', 1, 0)), sum(decode(estado, 'E', 1, 0))
          into v_can_item, v_can_ingresados, v_can_enviados
          from ge_dna_ord_transferencias_det
         where nro_ord_transferencia = p_nro_ord_transferencia;
     exception
       when others then
         v_can_item :=0;
         v_can_ingresados := 0;
         v_can_enviados := 0;
     end;

     if v_can_item = v_can_enviados then
        p_cod_res_cab := v_tra_completada; -- ingresada correctamente
     elsif v_can_item = v_can_ingresados then
        p_cod_res_cab := v_reg_correcto; -- ingresada pero pendiente de procesamiento
     else
        p_cod_res_cab := v_tra_proceso; -- proceso
     end if;

     FOR i IN c_item LOOP
      r_item.NRO_ITEM := i.nro_item;
      if i.estado = 'I' then
         r_item.COD_RETORNO := v_tra_pendiente;
      elsif i.estado = 'E' then
         r_item.COD_RETORNO := v_tra_enviado;
      elsif i.estado = 'A' then -- ver si se puede anular
         r_item.COD_RETORNO := v_tra_anulado;
      elsif i.estado = 'R' then -- ver si se puede rechazar
         r_item.COD_RETORNO := v_tra_rechazado;
      end if;

      begin
        select val_maximo
          into r_item.DES_RETORNO
          from ba_cod_referencias
         where dominio = 'COD_ERR_ORD_TRA_DNA'
           and val_minimo = r_item.COD_RETORNO;
      exception
        when others then
          r_item.DES_RETORNO := null;
      end;

      r_lista_item.extend;
      r_lista_item(r_lista_item.count) := r_item;
    END LOOP;

    p_item := r_lista_item;

    END IF;
    begin
      select val_maximo
        into p_des_res_cab
        from ba_cod_referencias
       where dominio = 'COD_ERR_ORD_TRA_DNA'
         and val_minimo = p_cod_res_cab;
    exception
      when others then
        p_des_res_cab := null;
    end;
  END;

  procedure pr_gen_dat_ext_aduana (p_nro_cuenta ge_cuentas.nro_cuenta%type default '1101700874', p_fec_movimiento date default null) is
    CURSOR cab_clie IS
      select a.cod_oficina, a.nro_cuenta, a.cod_persona, a.cod_modulo, a.cod_modalidad, c.cod_moneda
        from ge_cta_clientes a, ge_cuentas c
         where a.cod_modulo = c.cod_modulo
           and a.cod_modalidad = c.cod_modalidad
           and a.nro_cuenta = c.nro_cuenta
           and a.cod_modulo in (4, 3)
           and a.cod_modalidad in (41, 331)
           and a.relacion = 'P'
           and c.estado <> 'C'
           and a.nro_cuenta = p_nro_cuenta;
      --
    CURSOR det_clie(p_cta VARCHAR2, p_fec_movimiento date) IS
        SELECT x.fecha fec_movimiento, x.hora hor_movimiento, x.nro_secuencia, x.fec_valor, x.nro_documento,
               DECODE(fug_obt_tra_tipo(y.cod_transaccion,
                                       y.tipo,
                                       y.afecta), 'D', NVL(x.monto,0),0) mto_debito,
               DECODE(fug_obt_tra_tipo(y.cod_transaccion,
                                       y.tipo,
                                       y.afecta), 'C', NVL(x.MONTO,0), 0) mto_credito,
               t.descripcion, x.cod_mod_padre, x.cod_mad_padre, x.cod_tra_padre, x.concepto
          from cc_movimientos_his x, GE_TRANSACCIONES y, cc_cta_corrientes c, ge_transacciones t
         where x.nro_cuenta = p_cta
           and x.fecha = p_fec_movimiento
           and x.nro_cuenta = c.nro_cuenta
           and (x.REVERSADO = 'N' OR
               (x.REVERSADO = 'S' AND
                FEC_VALOR < p_fec_movimiento
           and EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV
                        WHERE x.FEC_VALOR = REV.FECHA
                          AND x.HOR_REVERSION  = REV.HORA
                          AND x.COD_USU_REVERSION = REV.COD_USUARIO
                          AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                          AND x.NRO_CUENTA = REV.NRO_CUENTA
                          AND abs(x.MONTO) = abs(REV.MONTO))) OR
               (x.REVERSADO = 'S' AND x.COD_TRA_PADRE in (303, 302) AND x.Cod_Mad_Padre = 455))
            AND x.ESTADO = 'N'
            AND x.NRO_FOLIO IS NULL
            AND x.COD_MODULO = y.COD_MODULO
            AND x.COD_MODALIDAD = y.COD_MODALIDAD
            AND x.COD_TRANSACCION = y.COD_TRANSACCION
            AND y.VE_CLIENTE = 'S'
            AND NVL(y.AFECTA,'XX') != 'B'
            AND y.TIPO IN ('C','D')
            AND x.cod_mod_padre = t.cod_modulo
            AND x.cod_mad_padre = t.cod_modalidad
            AND x.cod_tra_padre = t.cod_transaccion
          union all
          SELECT x.fecha fec_movimiento, x.hora hor_movimiento, x.nro_secuencia, x.fec_valor, x.nro_documento,
                 DECODE(fug_obt_tra_tipo(y.cod_transaccion,
                                         y.tipo,
                                         y.afecta), 'D', NVL(x.monto,0),0) mto_debito,
                 DECODE(fug_obt_tra_tipo(y.cod_transaccion,
                                         y.tipo,
                                         y.afecta), 'C', NVL(x.MONTO,0), 0) mto_credito,
               t.descripcion, x.cod_mod_padre, x.cod_mad_padre, x.cod_tra_padre, x.concepto
          from ah_movimientos_his x, GE_TRANSACCIONES y, ah_cta_vistas c, ge_transacciones t
         where x.nro_cuenta = p_cta
           and x.fecha = p_fec_movimiento
           and x.nro_cuenta = c.nro_cuenta
           and (x.REVERSADO = 'N' OR
               (x.REVERSADO = 'S' AND
                FEC_VALOR < p_fec_movimiento
           and EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV
                        WHERE x.FEC_VALOR = REV.FECHA
                          AND x.HOR_REVERSION  = REV.HORA
                          AND x.COD_USU_REVERSION = REV.COD_USUARIO
                          AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                          AND x.NRO_CUENTA = REV.NRO_CUENTA
                          AND abs(x.MONTO) = abs(REV.MONTO))) OR
               (x.REVERSADO = 'S' AND x.COD_TRA_PADRE in (303, 302) AND x.Cod_Mad_Padre = 455))
            AND x.ESTADO = 'N'
            AND x.NRO_FOLIO IS NULL
            AND x.COD_MODULO = y.COD_MODULO
            AND x.COD_MODALIDAD = y.COD_MODALIDAD
            AND x.COD_TRANSACCION = y.COD_TRANSACCION
            AND y.VE_CLIENTE = 'S'
            AND NVL(y.AFECTA,'XX') != 'B'
            AND y.TIPO IN ('C','D')
            AND x.cod_mod_padre = t.cod_modulo
            AND x.cod_mad_padre = t.cod_modalidad
            AND x.cod_tra_padre = t.cod_transaccion
         order by 1, 2;
     v_fec_movimiento ge_movimientos.fecha%type;
     v_sal_dia ge_ext_cli_cuentas.sal_actual%type;
     v_sal_act_det ge_ext_cli_cuentas.sal_actual%type;
     v_cod_extracto ge_dna_extractos.cod_extracto%type;
     v_sal_anterior ge_dna_extractos.sal_anterior%type;
     v_nro_doc_aduana  ge_dna_extractos_det.nro_doc_aduana%type := null;
     v_nro_liq_aduana  ge_dna_extractos_det.nro_liq_aduana%type := null;
     v_cta_destino     ge_dna_extractos_det.nro_cta_destino%type := null;
     v_concepto     ge_dna_extractos_det.concepto%type;
     v_mto_credito  ge_dna_extractos_det.mto_credito%type;
     v_mto_debito   ge_dna_extractos_det.mto_debito%type;
     v_fec_implementacion date := to_date(fug_obt_pardinamico('FDI_FEC_IMPLEMENTACION'), 'DD/MM/YYYY');
     v_sal_mes ge_dna_extractos.sal_anterior%type;
     v_sal_mes_ant ge_dna_extractos.sal_anterior%type;
     v_fec_ult_extracto cc_cta_corrientes.fec_ult_extracto%type;
     v_fec_ext_ant cc_cta_corrientes.fec_ult_extracto%type;
     v_exi_extracto varchar2(1);
  begin
    if p_fec_movimiento is null then
       v_fec_movimiento := fug_obt_fec_anterior(1);
    else
       v_fec_movimiento := p_fec_movimiento;
    end if;

    FOR c IN cab_clie LOOP
      begin
        select distinct 'S'
          into v_exi_extracto
          from ge_dna_extractos
         where fecha = v_fec_movimiento
           and nro_cuenta = c.nro_cuenta;
      exception
         when others then
           v_exi_extracto := 'N';
      end;
      
      if v_exi_extracto = 'S' then
         raise_application_error(-20000, 'El extracto a la DNA ya fue generado en la fecha.');
      end if;
      
      v_fec_ext_ant := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_movimiento, 1);
      
      if trunc(v_fec_implementacion) >= trunc(v_fec_movimiento) then
       begin 
          select s.sal_tot_cap
            into v_sal_anterior
            from ge_sal_diarios s
           where nro_cuenta = c.nro_cuenta
             and s.fecha = v_fec_ext_ant;
       exception
         when others then
           v_sal_anterior := 0;
       end;
      else      
        begin
          select sal_actual
            into v_sal_anterior
            from ge_dna_extractos x
           where x.nro_cuenta = c.nro_cuenta
             and x.fecha = v_fec_ext_ant
             and x.fecha < v_fec_movimiento;
        exception
          when others then
            v_sal_anterior := 0;
        end;
     end if;

     begin
       select s_cod_fir_ord_tra.nextval
         into v_cod_extracto
         from dual;
     exception
       when others then
         v_cod_extracto := 0;
     end;

     begin
       insert into ge_dna_extractos(cod_extracto, fecha, cod_modulo, cod_modalidad,
                                    cod_persona, nro_cuenta, cod_moneda, sal_anterior, sal_actual, estado)
            values( v_cod_extracto, v_fec_movimiento, c.cod_modulo, c.cod_modalidad,
                    c.cod_persona, c.nro_cuenta, c.cod_moneda, v_sal_anterior, 0, 'I');
     exception
       when others then
         raise_application_error(-20000, 'Error al insertar la Cabecera del Extracto Aduana. '||sqlerrm);
     end;

     v_sal_act_det := nvl(v_sal_anterior, 0);

     FOR d IN det_clie(c.nro_cuenta, v_fec_movimiento) LOOP
       if d.cod_tra_padre in (220, 219, 226) then
          begin
            select distinct i.iddepositodna, i.idticket
              into v_nro_doc_aduana, v_nro_liq_aduana
              from ge_dna_log i
             where i.iddepositodna is not null
               and i.iddepositobanco = d.nro_documento
               and trunc(i.fechaoperacion) = d.fec_valor;
          exception
            when others then
              v_nro_doc_aduana := null;
              v_nro_liq_aduana := null;
          end;

          begin
            select val_minimo
              into v_concepto
              from ba_cod_referencias
             where dominio = 'FDI_COD_CON_EXT'
               and val_maximo = d.cod_tra_padre;
          exception
            when others then
              v_concepto := null;
          end;
       elsif d.cod_tra_padre = 303 then
         begin
           select concepto
             into v_cta_destino
             from ge_snp_transferencias t
            where t.nro_referencia = d.nro_documento;
         exception
           when others then
             v_cta_destino := null;
         end;
         begin
           select val_minimo
             into v_concepto
             from ba_cod_referencias
            where dominio = 'FDI_COD_CON_EXT'
              and val_maximo = d.cod_tra_padre;
         exception
           when others then
             v_concepto := null;
         end;
         v_nro_doc_aduana := null;
         v_nro_liq_aduana := null;
       else
         v_nro_doc_aduana := null;
         v_nro_liq_aduana := null;
         v_concepto := null;
       end if;

       if d.mto_credito < 0 then
          v_mto_credito := 0;
          v_mto_debito := d.mto_credito*-1;
       else
          v_mto_credito := d.mto_credito;
       end if;

       if d.mto_debito < 0 then
         v_mto_credito := d.mto_debito*-1;
         v_mto_debito := 0;
       else
         v_mto_debito := d.mto_debito;
       end if;

       if v_concepto is null then
          if nvl(v_mto_credito, 0) > 0 then
             v_concepto := 'CRE';
          else
             v_concepto := 'DEB';
          end if;
       end if;

       v_sal_act_det := nvl(v_sal_act_det, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0);

       begin
          insert into ge_dna_extractos_det (cod_extracto, fecha, hora, nro_secuencia, fec_valor,
                                            nro_documento, cod_mod_padre, cod_mad_padre, cod_tra_padre,
                                            nro_cta_destino, mto_credito, mto_debito, saldo, nro_doc_aduana,
                                            nro_liq_aduana, concepto, observacion)
                                     values(v_cod_extracto, v_fec_movimiento, d.hor_movimiento, d.nro_secuencia, d.fec_valor,
                                            d.nro_documento, d.cod_mod_padre, d.cod_mad_padre, d.cod_tra_padre,
                                            v_cta_destino, v_mto_credito, v_mto_debito, v_sal_act_det, v_nro_doc_aduana,
                                            v_nro_liq_aduana, v_concepto, d.descripcion);
       exception
         when others then
           raise_application_error(-20000, 'Error al insertar el detalle del Extracto Aduana. '||sqlerrm);
        end;
     END LOOP;
     begin
       select sum(nvl(e.mto_credito, 0) - nvl(e.mto_debito, 0))
         into v_sal_dia
         from ge_dna_extractos_det e
        where e.cod_extracto = v_cod_extracto;
      exception
        when others then
          v_sal_dia := 0;
      end;
      begin
        update ge_dna_extractos e
           set e.sal_actual = nvl(e.sal_anterior, 0) + nvl(v_sal_dia, 0)
         where e.cod_extracto = v_cod_extracto;
      exception
        when others then
           raise_application_error(-20000, 'Error al actualizar el detalle del Extracto Aduana. '||sqlerrm);
      end;
    END LOOP;
  end;

  procedure pr_gen_ext_dna_xml(p_cod_extracto ge_dna_extractos.cod_extracto%type default null, p_nro_cuenta ge_cuentas.nro_cuenta%type default '1101700874', p_fec_movimiento date default null, p_ext_xml out clob ) is
    CURSOR c_cli (p_fec_movimiento ge_dna_extractos.fecha%type) is
      select c.cod_extracto, c.fecha, c.cod_modulo, c.cod_modalidad, c.cod_persona, c.nro_cuenta, c.cod_moneda,
             c.sal_anterior, c.sal_actual
        from ge_dna_extractos c
       where c.cod_extracto = nvl(p_cod_extracto, c.cod_extracto)
         and c.fecha = p_fec_movimiento
         and c.nro_cuenta =p_nro_cuenta;

    CURSOR c_mov (p_cod_extracto  ge_dna_extractos.cod_extracto%type) is
      select d.fecha, d.hora, d.nro_secuencia, d.fec_valor, d.nro_documento, d.cod_mod_padre,
             d.cod_mad_padre, d.cod_tra_padre, d.nro_cta_destino, d.mto_credito, d.mto_debito,
             d.saldo, d.nro_doc_aduana, d.nro_liq_aduana, d.concepto, d.observacion
        from ge_dna_extractos_det d
       where d.cod_extracto = p_cod_extracto
       order by fec_valor, hora;
    v_xml_extracto clob;
    v_salto        varchar2(2)    := CHR(13)||CHR(10);
    v_tab          varchar2(2)    := CHR(9);
    v_fec_movimiento  ge_dna_extractos.fecha%type;
  begin
    if p_fec_movimiento is null then
       v_fec_movimiento := fug_obt_fec_anterior(1);
    else
       v_fec_movimiento := p_fec_movimiento;
    end if;

    FOR c IN c_cli(v_fec_movimiento) LOOP
      v_xml_extracto := '<extracto Id="extracto">'||v_salto||
                        v_tab||'<idBanco>007</idBanco>'||v_salto||
                        v_tab||'<fechaExtracto>'||to_char(c.fecha, 'yyyymmdd')||'</fechaExtracto>'||v_salto||
                        v_tab||'<numeroCuenta>'||c.nro_cuenta||'</numeroCuenta>'||v_salto||
                        v_tab||'<saldoAnterior>'||c.sal_anterior||'</saldoAnterior>'||v_salto||
                        v_tab||'<saldoActual>'||c.sal_actual||'</saldoActual>'||v_salto||
                        v_tab||v_tab||'<movimientos>';
      for d in c_mov(c.cod_extracto) loop
        v_xml_extracto := v_xml_extracto||v_salto||
                          v_tab||v_tab||v_tab||'<concepto>'||d.concepto||'</concepto>'||v_salto||
                          v_tab||v_tab||v_tab||'<fechaTransaccion>'||to_char(d.fec_valor, 'yyyymmdd')||d.hora||'</fechaTransaccion>'||v_salto;
                          if d.nro_liq_aduana is not null then
                            v_xml_extracto := v_xml_extracto ||v_tab||v_tab||v_tab||'<idLiquidacion>'||d.nro_liq_aduana||'</idLiquidacion>'||v_salto;
                          end if;
                          v_xml_extracto := v_xml_extracto ||v_tab||v_tab||v_tab||'<idTransBanco>'||to_char(d.nro_documento)||'</idTransBanco>'||v_salto;
                          if d.nro_doc_aduana is not null then
                            v_xml_extracto := v_xml_extracto ||v_tab||v_tab||v_tab||'<idTransBandna>'||d.nro_doc_aduana||'</idTransBandna>'||v_salto;
                          end if;
                          v_xml_extracto := v_xml_extracto ||v_tab||v_tab||v_tab||'<montoCredito>'||to_char(d.mto_credito)||'/<montoCredito>'||v_salto||
                          v_tab||v_tab||v_tab||'<montoDebito>'||to_char(d.mto_debito)||'</montoDebito>'||v_salto||
                          v_tab||v_tab||v_tab||'<observacion>'||d.observacion||'</observacion>';
      end loop;
       v_xml_extracto := v_xml_extracto||v_salto||
                         v_tab||v_tab||'</movimientos>'||v_salto||
                         '</extracto>'||v_salto;
    end loop;
    p_ext_xml := v_xml_extracto;
  end;

  procedure pr_obt_ext_pendientes(p_typ_ext_xml out typ_listaextdnaxml)  is
     r_lista_ext    typ_listaextdnaxml := typ_listaextdnaxml();
     r_ext          typ_extdnaxml := typ_extdnaxml;
     CURSOR c_ext IS
     select cod_extracto, fecha, '007' cod_banco, nro_cuenta
       from ge_dna_extractos
      where estado = 'I';
  begin
    FOR c IN c_ext LOOP
      r_ext.cod_banco := c.cod_banco;
      r_ext.fec_extracto := c.fecha;
      r_ext.nro_cuenta := c.nro_cuenta;
      pr_gen_ext_dna_xml(c.cod_extracto, c.nro_cuenta, c.fecha, r_ext.ext_xml);
      r_lista_ext.extend;
      r_lista_ext(r_lista_ext.count) := r_ext;
    END LOOP;
    p_typ_ext_xml := r_lista_ext;
  end;

  procedure pr_act_est_extracto(p_fec_extracto ge_dna_extractos.fecha%type, p_nro_cuenta ge_dna_extractos.nro_cuenta%type, p_cod_retorno ge_dna_extractos.cod_retorno%type, p_msj_retorno ge_dna_extractos.msj_retorno%type)is
    v_estado ge_dna_extractos.estado%type;
  begin
    if p_cod_retorno = '00' then
       v_estado := 'P'; -- Procesado
    else
       v_estado := 'E'; -- con error
    end if;
    begin
      update ge_dna_extractos
         set estado = v_estado,
             cod_retorno = p_cod_retorno,
             msj_retorno = p_msj_retorno
       where fecha = p_fec_extracto
         and nro_cuenta = p_nro_cuenta;
     exception
       when others then
         raise_application_error(-20000, 'Error al actualizar el cod. Extracto de Aduana. '||sqlerrm);
     end;
  end;
end;
/

