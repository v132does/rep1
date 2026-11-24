CREATE OR REPLACE PROCEDURE IT.prv_pas_ven_sobregiros
 (P_NRO_CUENTA      IN GE_CUENTAS.NRO_CUENTA%TYPE default null,
  P_NRO_DOCUMENTO   IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE default null,
  P_CAU_CANCELACION IN CC_CTA_CORRIENTES.COD_CAU_CANCELACION%TYPE default null,
  P_CONCEPTO        IN GE_MOVIMIENTOS.CONCEPTO%TYPE default null,
  P_VER_ERROR       IN VARCHAR2 default null,
  P_NRO_LOTE        IN NUMBER DEFAULT NULL
 )
 IS
  v_impuesto           number(18,2);
  v_interes            number(18,2);
  v_tot_debito         number(18,2);
  v_fcdehoy            date;
  v_nro_secuencia      ge_movimientos.nro_secuencia%type :=0;
  v_hora               ge_movimientos.hora%type:= fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_nvo_cuenta         ge_cuentas.nro_cuenta%type;
  v_cod_persona        ba_personas.cod_persona%type;
  v_dia_sob            number(10);
  v_cod_can            number(10);
  v_val_tasa           ov_cta_vencidas.val_tasa%type;
  r_gmovi              ge_movimientos%rowtype;
  v_cotizacion         ge_cotizaciones.val_conversion%type ;
  v_cod_actividad      cr_age_actividades.cod_actividad%type;
  v_cod_mot_actividad  cr_age_mot_actividades.cod_mot_actividad%type;
  v_nro_referencia     cr_agendas.nro_referencia%type;
  v_est_cuenta         ge_movimientos.est_cuenta%type;

  cursor sobregiros is
    select cta.nro_cuenta,res.can_dias,res.sit_deuda,cta.cod_modulo,cta.cod_modalidad,
           cta.cod_oficina,cta.denominacion,cta.sal_total, cta.sal_bloqueado, cta.sal_retenido,
           cta.mto_cre_pendientes,cta.mto_deb_pendientes,cta.mto_cre_a_confirmar,cta.tas_personalizada,
           cta.aut_pendiente, cta.tra_prohibida,cta.cod_moneda,
           cta.cta_combinada,cta.reg_firma,cta.max_atraso,cta.pro_atraso
      from cc_sobregiros_res res,
           cc_cta_corrientes cta
     where res.can_dias(+) >= decode(p_nro_cuenta,null,v_dia_sob,res.can_dias(+))
       and cta.nro_cuenta = nvl(p_nro_cuenta,res.nro_cuenta)
       and res.nro_cuenta(+) = cta.nro_cuenta
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

 /*Procedimiento para cargar los TITULOS EJECUTIVOS*/
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

  --Obtener el parametro de cantidad de dias1
   v_dia_sob := fug_obt_pardinamico('DIA_SOB_VEN');
   v_cod_can := nvl(P_CAU_CANCELACION,fug_obt_pardinamico('COD_CAU_CAN_SOBREGIRO'));
   v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
   v_hora    := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
   
   --Obtener la(s) cuenta(s) que pasa(ran) a sobregiros vencidos
   for cta in sobregiros loop
       v_nro_secuencia := 0;
       If p_nro_cuenta is not null then --cuando es manual
          if nvl(cta.sal_bloqueado, 0) > 0 then
             if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   901,
                                   'Pase a Vencido. La cuenta tiene saldo bloqueado',
                                   NULL,
                                   NULL,
                                   NULL,
                                   P_NRO_LOTE);
             else
                raise_application_error(-20000,'La cuenta tiene saldo bloqueado');
             end if ;
          elsIf nvl(cta.sal_retenido, 0) > 0 then
             if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   902,
                                   'Pase a Vencido. La cuenta tiene saldo retenido',
                                   NULL,
                                   NULL,
                                   NULL,
                                   P_NRO_LOTE);
             else
                raise_application_error(-20000,'La cuenta tiene saldo retenido');
             end if;
          elsif nvl(cta.mto_cre_pendientes, 0) > 0 then
             if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   903,
                                   'Pase a Vencido. La cuenta tiene créditos fuera de hora',
                                   NULL,
                                   NULL,
                                   NULL,
                                   P_NRO_LOTE);
             else
                raise_application_error(-20000,'La cuenta tiene créditos fuera de hora');
             end if ;
          elsif nvl(cta.mto_deb_pendientes, 0) > 0 then
             if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   903,
                                   'Pase a Vencido. La cuenta tiene débitos fuera de hora',
                                   NULL,
                                   NULL,
                                   NULL,
                                   P_NRO_LOTE);
             else
                raise_application_error(-20000,'La cuenta tiene débitos fuera de hora');
             end if ;
          elsif nvl(cta.mto_cre_a_confirmar, 0) > 0 then
             if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   904,
                                   'Pase a Vencido. La cuenta tiene créditos fuera de hora a confirmar',
                                   NULL,
                                   NULL,
                                   NULL,
                                   P_NRO_LOTE);
             else 
                raise_application_error(-20000,'La cuenta tiene créditos fuera de hora a confirmar');
             end if ;
          elsif cta.cta_combinada = 'S' Then
             if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   905,
                                   'Pase a Vencido. La cuenta participa en cuenta combinada',
                                   NULL,
                                   NULL,
                                   NULL,
                                   P_NRO_LOTE);
             else
                raise_application_error(-20000,'La cuenta participa en cuenta combinada');
             end if ;
          End if;
     End if;
     If (p_nro_cuenta is null and
        nvl(cta.sal_bloqueado,0) = 0 and
        nvl(cta.sal_retenido, 0) = 0 and
        nvl(cta.mto_cre_pendientes, 0) = 0 and
        nvl(cta.mto_deb_pendientes, 0) = 0 and
        nvl(cta.mto_cre_a_confirmar, 0) = 0 and  --cuando es automatico
        cta.cta_combinada = 'N') or
        p_nro_cuenta is not null Then --cuando es manual
        
      
        IF cta.can_dias < 61 THEN
          v_est_cuenta := 'N'; ---DYDMR-4007 NAD 03/06/2016
        -- C.B. 20/08/2012 - BBVASOP-1150
        ELSIF cta.can_dias > 60 and cta.can_dias < 91 THEN
           v_est_cuenta := 'V';
        ELSIF cta.can_dias > 90 AND cta.can_dias < 181 THEN
           v_est_cuenta := 'G';
        ELSIF cta.can_dias > 180 THEN
           v_est_cuenta := 'M';
        ELSE
           v_est_cuenta := 'N'; --PCCRPDNE-153
        END IF;
        
        --recuperar interes e impuesto para acreditar luego
        pac_sob.PR_PRO_LIQ_SOB(cta.nro_cuenta,
                               'N', --(N) no va a procesar, sólo calcula
                               v_impuesto,
                               v_interes);
       v_tot_debito := abs(cta.sal_total)+nvl(v_impuesto,0)+nvl(v_interes,0);

    	 pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);

       --Realizar la liquidacion del sobregiro
       prc_liq_sobregiros(cta.nro_cuenta);

       --Credito a la cuenta
       v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

    	 pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);

       if cta.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
          select pag_gen.FU_OBT_COTIZACION(pag_gen.FU_OBT_MON_FUERTE) into v_cotizacion from dual;
       else v_cotizacion := null;
       end if;

       v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

       pag_cta.pr_act_operacion(cta.nro_cuenta,
       				v_hora,  --HORA
       				'C',
       				cta.cod_moneda,
       				v_tot_debito,
       				602,     --COD_TRA_PADRE
       				602,
       				nvl(p_nro_documento,cta.nro_cuenta),
       				v_cotizacion,                      --COTIZACION
       				cta.cod_oficina,                   --cod_ofi_origen
       				4,                                 --cod_mod_padre
      				41,                                --cod_mad_padre
      				null,                              --cod_tasa
      				null,                              --val_tasa
      				nvl(p_concepto,'Traspaso a sobregiro vencido'),
      				'N',                     --emi_aviso
      				v_nro_secuencia,
      				trunc(v_fcdehoy));

       if pag_cta.fu_obt_cod_error() <> 0 then
          if nvl(P_VER_ERROR, 'X') = 'S' then
                pag_nom.pr_ins_log(p_nro_cuenta,
                                   pag_cta.fu_obt_cod_error(),
                                   pag_cta.fu_obt_msj_error(),
                                   NULL,
                                   NULL,
                                   NULL);
          else
             raise_application_error(-20001,pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
          end if ;
       End if;

       --Actualizar la causa de cancelación
       update cc_cta_corrientes
          set cod_cau_cancelacion = v_cod_can
        where nro_cuenta = cta.nro_cuenta;
       /*
       || DYDMR-21 - SPI 2509
       || La cuenta corriente ya no tiene sobregiros.
       || Los sobregiros en suspenso no deben considerarse en el procedimiento PRC_REV_SOB_SUSPENSO
       || xpy0038 - 06/mayo/2014
       */
       update cc_sob_suspenso
          set fec_regularizacion = v_fcdehoy
        where nro_cuenta = cta.nro_cuenta
          and fec_regularizacion is null;
       --- Fin modificaciones DYDMR-21
       
       v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

    	-- pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);
        pag_cta.PR_SET_VARIABLES (user, v_fcdehoy, '358', 'N', 'N', v_nro_secuencia);
       --Pasar al estado cancelado
       pag_cta .PR_ACT_ESTADO(cta.nro_cuenta,'C', v_fcdehoy,v_hora,nvl(p_nro_documento,cta.nro_cuenta));
       --- DYDMR-21: Cuenta puede tener débitos automáticos u otro
       if pag_cta.fu_obt_cod_error() <> 0 then
          raise_application_error(-20001,pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
       End if;
       --Obtener el nvo nro de cuenta
       v_nvo_cuenta := fug_obt_sig_nro_cuenta(15,
                                              153,
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

       --Inserta el registro operacion vencida
       /*
       15 - MODULO DE OPERACIONES VENCIDAS
       153 - CUENTAS CORRIENTES VENCIDAS
       */
       /*
       Entrará como V = Vencida
       */

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
                            values (15,                    153,
                                    cta.cod_oficina,      v_nvo_cuenta,
                                    cta.nro_cuenta,       cta.cod_moneda,
                                    cta.denominacion,     v_fcdehoy,
                                    v_est_cuenta,         v_fcdehoy,
                                    v_tot_debito,         v_tot_debito,
                                    cta.can_dias,         cta.can_dias,
                                    v_fcdehoy-nvl(cta.can_dias,0), --DYDMR-4894 Se elimina el formateo de fechas
                                    v_val_tasa,           v_fcdehoy,
                                    v_est_cuenta);

       --- Calcular los días de atraso
      -- PRV_CAL_ATRASOS(v_nvo_cuenta);--DYDMR-6244 - 08/03/2017 - se comenta el procedimiento ya que no corresponde el
                                       --calculo de dias de atraso en el momento de traspaso de la cta a operacion vencida
                                       --porque el procedimiento corre en el cierre(proceso 10 y 11).
       --- Insertar relacion PRINCIPAL cliente cuentas
       for rel in rel_cta(cta.nro_cuenta) loop
         insert into ge_cta_clientes
           (cod_persona, nro_cuenta, dig_verificador,
            cod_oficina, cod_modulo, cod_modalidad, relacion)
         values
           (rel.cod_persona, v_nvo_cuenta, rel.dig_verificador,
            rel.cod_oficina, 15, 153, rel.relacion);
            v_cod_persona := rel.cod_persona;
       end loop;

        --- Insertar relacion OTRAS cliente cuentas
       for rel_o in rel_cta_o(cta.nro_cuenta) loop
         insert into ge_cta_clientes
           (cod_persona, nro_cuenta, dig_verificador,
            cod_oficina, cod_modulo, cod_modalidad, relacion)
         values
           (rel_o.cod_persona, v_nvo_cuenta, rel_o.dig_verificador,
            rel_o.cod_oficina, 15, 153, rel_o.relacion);
       end loop;

       --- Insertar Garantias si las hubieran...
       for gr in gar(cta.nro_cuenta) loop

         insert into ov_cta_garantias(nro_cuenta,
                                      nro_garantia,
                                      cod_garantia,
                                      mto_aplicado)
                               values(v_nvo_cuenta,
                                      gr.nro_garantia,
                                      gr.cod_garantia,
                                      gr.mto_aplicado);
       end loop;
        -- genero el telegrama respectivo
        if nvl(P_VER_ERROR, 'N') = 'N' then
           prv_gen_telegrama(cta.nro_cuenta,153,v_tot_debito,v_tot_debito,cta.cod_moneda,v_cod_persona);
        end if;


        --Hacer un registro en Ge_Movimiento por la
        --Entrada de la cuenta a Operaciones Vencidas


       /*  Fmolians DYDMR-883  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        --pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);*/
        
        pag_cta.PR_SET_VARIABLES (user, null, '358', 'C', 'N', v_nro_secuencia);
        
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := user;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fcdehoy;
        r_gmovi.cod_modulo         := 15;
        r_gmovi.cod_modalidad      := 153;
        r_gmovi.cod_oficina        := cta.cod_oficina;
        r_gmovi.nro_cuenta         := v_nvo_cuenta;
        r_gmovi.cod_moneda         := cta.cod_moneda;
        r_gmovi.tip_mov_rubro      := 'C';
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
        r_gmovi.nro_documento      := nvl(p_nro_documento,cta.nro_cuenta);
        r_gmovi.concepto           := nvl(p_concepto,'Pasar a vencido la cta.='||cta.nro_cuenta);
        r_gmovi.est_cuenta         := v_est_cuenta;

        pag_gen.pr_ins_ge_movimiento(r_gmovi);

       /*Se graban los titulos ejecutivos*/
        titulos(cta.nro_cuenta,cta.cod_moneda,v_tot_debito,v_fcdehoy);

        /*Si se desea agendar la impresion de cada uno de los titulos ejecutivos,
         agregamos en la agenda*/
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
    if nvl(P_VER_ERROR, 'X') = 'S' then
       pag_nom.pr_ins_log(p_nro_cuenta,
                          906,
                          'Error no previsto en proceso de Pase a Vencido',
                           NULL,
                           NULL,
                           NULL,
                           P_NRO_LOTE);
    else 
       If sqlcode <= -20000 then
          raise;
       else
          raise_application_error(-20001,'Error: En el proceso de sobregiros vencidos... '||sqlerrm);
       End if ;
    end if;
end;
/
