CREATE OR REPLACE PROCEDURE IT.PRG_REC_SOBREGIROS
      (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
       P_CAN_DIAS   IN CC_SOBREGIROS_RES.CAN_DIAS%TYPE,
       P_REF_LOTE   IN GE_SAL_INV_VTA_CARTERA_HIS.REF_LOTE%TYPE) IS
  v_tot_debito         number(18,2);
  v_fcdehoy            date;
  v_nro_secuencia      ge_movimientos.nro_secuencia%type :=0;
  v_hora               ge_movimientos.hora%type:= fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_nvo_cuenta         ge_cuentas.nro_cuenta%type;
  v_cod_persona        ba_personas.cod_persona%type;
  v_val_tasa           ov_cta_vencidas.val_tasa%type;
  r_gmovi              ge_movimientos%rowtype;
  v_cotizacion         ge_cotizaciones.val_conversion%type ;
  v_cod_actividad      cr_age_actividades.cod_actividad%type;
  v_cod_mot_actividad  cr_age_mot_actividades.cod_mot_actividad%type;
  v_nro_referencia     cr_agendas.nro_referencia%type;
  v_est_cuenta         ge_movimientos.est_cuenta%type;
  v_mon_previ          gv_movimientos.MONTO%type;
  v_hor_cancel         ge_sal_inv_vta_cartera_his.hor_cancelacion%type;
  v_fec_venta          ge_sal_inv_vta_cartera_his.fec_venta%type;
  v_sal_capital        ge_sal_inv_vta_cartera_his.mto_deu_mon_cuenta%type;
  v_por_prevision      number;
  v_mto_impuesto       number;
  v_mto_interes        number;
  v_fec_anterior       date;

  cursor sobregiros is
    select nro_cuenta, cod_modulo, cod_modalidad, cod_oficina, denominacion, sal_total, sal_bloqueado,
           sal_retenido, mto_cre_pendientes, mto_deb_pendientes, mto_cre_a_confirmar, tas_personalizada,
           aut_pendiente, tra_prohibida, cod_moneda, cta_combinada, reg_firma, max_atraso, pro_atraso
      from cc_cta_corrientes cta
     where cta.nro_cuenta = p_nro_cuenta
       and (cta.sal_total - cta.sal_retenido) < 0
       and cta.estado <> 'C';

  cursor rel_cta(p_cuenta varchar2) is
    select cod_persona,
           dig_verificador,
           cod_oficina,
           cod_modulo,
           cod_modalidad,
           relacion
      from ge_cta_clientes
     where nro_cuenta = p_cuenta
       and relacion = 'P';

  cursor rel_cta_o(p_cuenta varchar2) is
    select cod_persona,
           dig_verificador,
           cod_oficina,
           cod_modulo,
           cod_modalidad,
           relacion
      from ge_cta_clientes
     where nro_cuenta = p_cuenta
       and relacion <> 'P';

  cursor gar(p_cuenta varchar2) is
    select nro_cuenta,
           cod_garantia,
           nro_garantia,
           sum(mto_aplicado) mto_aplicado
      from pv_operaciones_det
     where nro_cuenta = p_cuenta
     and cod_garantia is not null
     group by nro_cuenta,
           cod_garantia,
           nro_garantia;

  procedure titulos(cuenta in varchar2,
                    moneda in varchar2,
                    importe in number,
                    fechoy in date) is
    cursor titulares is
      select b.nom_completo Nombre
        from ge_cta_clientes a, ba_personas b
       where a.cod_persona = b.cod_persona
         and a.nro_cuenta = cuenta;
    v_titulares varchar2(1200);
  begin
    for r in titulares loop
     v_titulares := v_titulares||' * '||r.nombre;
    end loop;
    insert into cc_tit_ejecutivos(nro_cuenta,cod_moneda,titulares,mto_sobregiro,fecha)
                               values(cuenta,moneda,v_titulares,importe,fechoy);
  end;

begin

 begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=4; end;

   v_fcdehoy      := pag_cal.fu_obt_fec_actual(4);
   v_fec_anterior := pag_cal.FU_OBT_FEC_ANTERIOR(4);
   v_hora         := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);

   --Obtener la(s) cuenta(s) que pasa(ran) a sobregiros vencidos
   for cta in sobregiros loop
       v_nro_secuencia := 0;
     If (p_nro_cuenta is null and
        nvl(cta.sal_bloqueado,0) = 0 and
        nvl(cta.sal_retenido, 0) = 0 and
        nvl(cta.mto_cre_pendientes, 0) = 0 and
        nvl(cta.mto_deb_pendientes, 0) = 0 and
        nvl(cta.mto_cre_a_confirmar, 0) = 0 and  --cuando es automatico
        cta.cta_combinada = 'N') or
        p_nro_cuenta is not null Then --cuando es manual

        IF P_CAN_DIAS < 91 THEN
           v_est_cuenta := 'V';
        ELSIF P_CAN_DIAS > 90 AND P_CAN_DIAS < 181 THEN
           v_est_cuenta := 'G';
        ELSIF P_CAN_DIAS > 180 THEN
           v_est_cuenta := 'M';
        END IF;

       begin
          select r.fec_venta, r.hor_cancelacion, mto_deu_mon_cuenta
            into v_fec_venta, v_hor_cancel, v_sal_capital
            from ge_sal_inv_vta_cartera_his r
           where r.ref_lote = P_REF_LOTE
             and r.nro_cuenta = P_NRO_CUENTA;
          ----
          select a.MONTO
            into v_mon_previ
            from gv_movimientos a
           where a.FECHA = v_fec_venta
             and a.HORA = v_hor_cancel
             and a.COD_TRA_PADRE = 957
             and a.COD_TRANSACCION = 957;
        exception
           WHEN OTHERS THEN
             raise_application_error(-20000,'Error obtener monto prevision de Ope. Vencida '||Sqlerrm);
        end;

       begin
         select a.monto
           into v_mto_impuesto
           from gv_movimientos a
          where a.fecha = v_fec_venta
            and a.hora = v_hor_cancel
            and a.cod_tra_padre = 319
            and a.cod_transaccion = 523;
       exception
         when no_data_found then
           v_mto_impuesto := 0;
         when others then
           raise_application_error(-20000,'Error al buscar el impuesto del sobregiro.');
       end;
       --
       begin
         select a.monto
           into v_mto_interes
           from gv_movimientos a
          where a.fecha = v_fec_venta
            and a.hora = v_hor_cancel
            and a.cod_tra_padre = 550
            and a.cod_transaccion = 550;
       exception
         when no_data_found then
           v_mto_interes := 0;
         when others then
           raise_application_error(-20000,'Error al buscar el mto. interés del sobregiro.');
       end;

        -- v_tot_debito corresponde al saldo de la cta. antes de la venta.
       v_tot_debito := v_sal_capital - nvl(v_mto_impuesto,0) - nvl(v_mto_interes,0);

       if cta.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
          select pag_gen.FU_OBT_COTIZACION(pag_gen.FU_OBT_MON_FUERTE) into v_cotizacion from dual;
       else v_cotizacion := null;
       end if;

       --Actualizar la causa de cancelación (500 - DECISION DEL BCO: VENTA CARTERA)
       update cc_cta_corrientes
          set cod_cau_cancelacion = 500
        where nro_cuenta = cta.nro_cuenta;

       update cc_sob_suspenso
          set fec_regularizacion = v_fcdehoy
        where nro_cuenta = cta.nro_cuenta
          and fec_regularizacion is null;

        v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

        pag_cta.pr_act_operacion(cta.nro_cuenta,
                v_hora,  --HORA
                'C',
                cta.cod_moneda,
                v_tot_debito,
                602,     --COD_TRA_PADRE
                602,
                nvl(P_REF_LOTE,cta.nro_cuenta),
                v_cotizacion,                      --COTIZACION
                cta.cod_oficina,                   --cod_ofi_origen
                4,                                 --cod_mod_padre
                41,                                --cod_mad_padre
                null,                              --cod_tasa
                null,                              --val_tasa
                'Recap. Vta. Car. Traspaso Sob.Vencido',
                'N',                     --emi_aviso
                v_nro_secuencia,
                trunc(v_fcdehoy));

        if pag_cta.fu_obt_cod_error() <> 0 then
           raise_application_error(-20001,pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
        End if;

       pag_cta.PR_SET_VARIABLES(user, null, '358', 'N', 'N', v_nro_secuencia);

       --Pasar al estado cancelado
       pag_cta.PR_ACT_ESTADO(cta.nro_cuenta,'C', v_fcdehoy,v_hora,cta.nro_cuenta);
       if pag_cta.fu_obt_cod_error() <> 0 then
          raise_application_error(-20001,pag_cta.fu_obt_cod_error()||' - '||pag_cta.fu_obt_msj_error());
       End if;
       v_nro_secuencia  := nvl(v_nro_secuencia,0) + 1;
       --Obtener el nvo nro de cuenta
       v_nvo_cuenta := fug_obt_sig_nro_cuenta(cta.cod_modulo,
                                              cta.cod_modalidad,
                                              cta.cod_oficina,
                                              cta.cod_moneda,
                                              v_cod_persona);
       --Obtener el valor de la tasa
       v_val_tasa := fug_obt_val_tasa(cta.cod_modulo,
                                      cta.cod_modalidad,
                                      cta.cod_oficina,
                                      cta.nro_cuenta,
                                      cta.cod_moneda,
                                      0, --monto
                                      cta.tas_personalizada,
                                      NULL, --cod_tasa
                                      550, --Transaccion de sobregiro
                                      v_fcdehoy);

       /* Inserta el registro operacion vencida
       15 - MODULO DE OPERACIONES VENCIDAS
       152 - CUENTAS CORRIENTES VENCIDAS */
        insert into ov_cta_vencidas(cod_modulo,           cod_modalidad,
                                    cod_oficina,          nro_cuenta,
                                    nro_cta_origen,       cod_moneda,
                                    denominacion,         fec_apertura,
                                    estado,               fec_cam_estado,
                                    mto_origen,           sal_total,
                                    dia_atr_inicial,      dia_atraso,
                                    fec_ini_mora,
                                    val_tasa,             fec_ult_movimiento,
                                    est_batch)
                            values (15,                    152,
                                    cta.cod_oficina,      v_nvo_cuenta,
                                    cta.nro_cuenta,       cta.cod_moneda,
                                    cta.denominacion,     v_fcdehoy,
                                    v_est_cuenta,         v_fcdehoy,
                                    v_tot_debito,         v_tot_debito,
                                    P_CAN_DIAS,           P_CAN_DIAS,
                                    v_fcdehoy-nvl(P_CAN_DIAS,0),
                                    v_val_tasa,           v_fcdehoy,
                                    v_est_cuenta);

       -- Hacer un registro en Ge_Movimiento por la entrada de la cuenta a Operaciones Vencidas

        v_nro_secuencia            := nvl(v_nro_secuencia,0) + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := user;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fcdehoy;
        r_gmovi.cod_modulo         := 15;
        r_gmovi.cod_modalidad      := 152;
        r_gmovi.cod_oficina        := cta.cod_oficina;
        r_gmovi.nro_cuenta         := v_nvo_cuenta;
        r_gmovi.cod_moneda         := cta.cod_moneda;
        r_gmovi.tip_mov_rubro      := 'D';
        r_gmovi.cod_tra_padre      := 358;
        r_gmovi.cod_transaccion    := 711;
        r_gmovi.monto              := v_tot_debito;
        r_gmovi.fec_valor          := v_fcdehoy;
        r_gmovi.emi_aviso          := 'S';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := cta.cod_oficina;
        r_gmovi.cod_mod_padre      := 4;
        r_gmovi.cod_mad_padre      := 41;
        r_gmovi.nro_documento      := cta.nro_cuenta;
        r_gmovi.concepto           := 'Pasar a vencido la cta.= '||cta.nro_cuenta;
        r_gmovi.est_cuenta         := v_est_cuenta;

        pag_gen.pr_ins_ge_movimiento(r_gmovi);

       --- Calcular los días de atraso
       PRV_CAL_ATRASOS(v_nvo_cuenta);


        v_por_prevision := round(((v_mon_previ/v_sal_capital) * 100),2);

        INSERT INTO ov_previsiones(fecha, nro_cuenta, monto, saldo, porcentaje, tot_gar_computables, tot_pri_prevision)
        VALUES (v_fec_anterior, v_nvo_cuenta, v_mon_previ, nvl(v_tot_debito,v_sal_capital), v_por_prevision, 0, 0);


       --- Insertar relacion PRINCIPAL cliente cuentas
       for rel in rel_cta(cta.nro_cuenta) loop
         insert into ge_cta_clientes
           (cod_persona, nro_cuenta, dig_verificador,
            cod_oficina, cod_modulo, cod_modalidad, relacion)
         values
           (rel.cod_persona, v_nvo_cuenta, rel.dig_verificador,
            rel.cod_oficina, 15, 152, rel.relacion);

            v_cod_persona := rel.cod_persona;
       end loop;

       --- Insertar relacion OTRAS cliente cuentas
       for rel_o in rel_cta_o(cta.nro_cuenta) loop
         insert into ge_cta_clientes
           (cod_persona, nro_cuenta, dig_verificador,
            cod_oficina, cod_modulo, cod_modalidad, relacion)
         values
           (rel_o.cod_persona, v_nvo_cuenta, rel_o.dig_verificador,
            rel_o.cod_oficina, 15, 152, rel_o.relacion);
       end loop;

       --- Insertar Garantias si las hubieran...
       for gr in gar(cta.nro_cuenta) loop
         insert into ov_cta_garantias
           (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado)
         values
           (v_nvo_cuenta, gr.nro_garantia, gr.cod_garantia, gr.mto_aplicado);
       end loop;

       --- genero el telegrama respectivo
       prv_gen_telegrama(cta.nro_cuenta,152,v_tot_debito,v_tot_debito,cta.cod_moneda,v_cod_persona);

       /*Se graban los titulos ejecutivos*/
        titulos(cta.nro_cuenta,cta.cod_moneda,v_tot_debito,v_fcdehoy);

       /*Si se desea agendar la impresion de cada uno de los titulos ejecutivos, agregamos en la agenda*/
        if nvl(fug_obt_pardinamico('IND_AGEN_PRINT_TITULOS'), 'N') = 'S' then
          v_cod_actividad := nvl(fug_obt_pardinamico('COD_AGE_ACTIV_TE'), 1);
          v_cod_mot_actividad :=  nvl(fug_obt_pardinamico('COD_AGE_MOT_ACT_TE'), 1);
          PRG_GEN_AGE_ACTIVIDADES(v_cod_persona,
                                  substr(user,1,10),
                                  v_cod_actividad,
                                  1,
                                  v_cod_mot_actividad,
                                  v_fcdehoy,
                                  'Recordar imprimir el Titulo Ejecutivo',
                                  v_nro_referencia);
        end if;

     End if;
   end loop;
exception
  when others then
       If sqlcode <= -20000 then
          raise;
       else
          raise_application_error(-20001,'Error: En el proceso de sobregiros vencidos... '||sqlerrm);
       End if;
end;
/

