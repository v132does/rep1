CREATE OR REPLACE PROCEDURE IT.PRV_PAS_VEN_TARJETAS
 IS

   v_fcdehoy       ge_movimientos.fecha%type;
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_hora          ge_movimientos.hora%type;
   v_nvo_cuenta    ge_cuentas.nro_cuenta%type;
   v_cod_persona   ba_personas.cod_persona%type;
   r_gmovi         ge_movimientos%rowtype;
   v_cat_cuenta    ge_movimientos.est_cuenta%type;

  cursor tarjetas is
    select a.nro_cuenta NroCta,
           b.nro_tarjeta NroTarjeta,
           c.mto_operacion MtoVencido,
           a.cod_oficina Oficina,
           a.cod_moneda Moneda,
           a.denominacion Denominacion,
           a.dia_mora Mora,
           a.cod_modulo Modulo,
           a.cod_modalidad Modalidad,
           a.tas_financiacion val_tasa,
           c.rowid Fila,
           a.cod_modalidad
      from ta_cta_tarjetas a,
           ta_tarjetas b,
           ta_mov_especiales_tmp c
     where a.nro_cuenta = b.nro_cuenta
       and b.nro_cuenta = a.nro_cuenta
       and b.nro_cuenta = to_char(to_number(c.nro_cuenta))
       --and substr(b.nro_tarjeta,13,4) = c.nro_tarjeta--||c.dig_verificador
       and b.nro_tarjeta = c.nro_tarjeta--||c.dig_verificador
     --  and a.estado <> 'C'
       and upper(replace(c.des_movimiento,' ','')) = 'PASEAVENCIDA'
       and not exists (select 1 from ov_cta_vencidas v where v.nro_cta_origen = a.nro_cuenta) ;

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
    select distinct
           a.nro_cuenta,
           a.cod_garantia,
           a.nro_garantia,
           a.mto_aplicado,
           a.mto_apl_computable
      from ta_cta_garantias a
     where  a.nro_cuenta =  p_cuenta;
     
begin

  /* Segun el mail de fecha : 02-10-2007
    1- Recibir el archivo de movimientos especiales
       donde cada registro será identificado de acuerdo a la
       descripción PASE  A VENCIDA (adjunto el mail enviado por la señora Isabel)
    2- Al momento de procesar los movimientos  especiales para pase a
       Operaciones Vencidas:
       a- Se va a cancelar la tarjeta en  GF.
       b- Dar de alta una nueva cuenta en  Operaciones Vencidas con el monto imputado en Bancard.
    3- Para informar a Bancard las cuentas  canceladas por pase a
       Operaciones Vencidas se seguirá realizando en forma
       manual como lo es actualmente.*/
   /* Otras deficiones
   1- Para ello creacion la tabla temporal TA_CTA_VENCIDAS_TMP en la cual se deposita
      la informacion que se trae del archivo TMVENPF que envia Bancard.
   2- Este procedimiento tomará los datos inmediatamente despues de importar el
      archivo y realizará dos movimientos
      a) Pasa a CANCELADA la cuenta de la tarjeta de credito y la tarjeta.
      b) Crea un registro en Operaciones vencidas con el monto que trae el archivo de
         Bancard.*/
   v_fcdehoy := pag_cal.fu_obt_fec_actual(5);
   v_hora    := to_char(sysdate,'hh24:mi:ss');

  begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;

  for r in tarjetas loop
     IF r.mora < 61 THEN
       v_cat_cuenta := 'N';---DYDMR-4007 NAD 03/06/2016
     -- C.B. 17/08/2012 - BBVASOP-1123
     ELSIF r.mora >60 and r.mora < 91 THEN
        v_cat_cuenta := 'V';
     ELSIF r.mora > 90 AND r.mora < 181 THEN
        v_cat_cuenta := 'G';
     ELSIF r.mora > 180 THEN
        v_cat_cuenta := 'M';
     END IF;
   
     begin
         r_gmovi := null;
         v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
         
         -- 26/06/2013-EC-CL : Cuando la secuencia llega a 997, vuelve a 1
         if v_nro_secuencia >= 997 then
            v_nro_secuencia :=1;
            v_hora :=  pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         end if;
        --
                
         --pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);

         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.cod_usuario        := user;
         r_gmovi.hora               := v_hora;
         r_gmovi.fecha              := v_fcdehoy;
         r_gmovi.cod_modulo         := r.modulo;
         r_gmovi.cod_modalidad      := r.modalidad;
         r_gmovi.cod_oficina        := r.oficina;
         r_gmovi.nro_cuenta         := r.NroCta;
         r_gmovi.cod_moneda         := r.moneda;
         r_gmovi.cod_tra_padre      := 358;
         r_gmovi.cod_transaccion    := 45;
         r_gmovi.monto              := r.mtovencido;
         r_gmovi.fec_valor          := v_fcdehoy;
         r_gmovi.emi_aviso          := 'S';
         r_gmovi.reversado          := 'N';
         r_gmovi.protegido          := 'N';
         r_gmovi.estado             := 'N';
         r_gmovi.cod_ofi_origen     := r.oficina;
         r_gmovi.cod_mod_padre      := 15;
         r_gmovi.cod_mad_padre      := 151;
         r_gmovi.nro_documento      := r.nrocta;
         r_gmovi.concepto           := 'Traspaso a operaciones vencidas';
         r_gmovi.est_cuenta         := v_cat_cuenta;
         
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      exception
         when others then
            raise_application_error(-20001,'Error al insertar movimiento de baja de Tarj. Cred. Cuenta:'||r.nrocta||' '||sqlerrm);
      end;

    --Obtener el nvo nro de cuenta
    v_nvo_cuenta := fug_obt_sig_nro_cuenta(15,
                                           151,
                                           r.oficina,
                                           r.moneda,
                                           v_cod_persona);
    begin
      insert into ov_cta_vencidas
        (cod_modulo,           cod_modalidad,
         cod_oficina,          nro_cuenta,
         nro_cta_origen,       cod_moneda,
         denominacion,         fec_apertura,
         estado,               fec_cam_estado,
         mto_origen,           sal_total,
         dia_atr_inicial,      dia_atraso,
         fec_ini_mora,
         val_tasa,             fec_ult_movimiento,
   est_batch)
      values
        (15,                    151,
         r.oficina,             v_nvo_cuenta,
         r.nrocta,              r.moneda,
         r.denominacion,        v_fcdehoy,
         v_cat_cuenta,          v_fcdehoy,
         r.mtovencido,          r.mtovencido,
         r.mora,                r.mora,
         v_fcdehoy-nvl(r.mora,0),
         r.val_tasa,            v_fcdehoy,
   v_cat_cuenta);
    exception
      when others then
        raise_application_error(-20004,'Error al insertar en ov_cta_vencidas. Cuenta:'||r.nrocta||' '||sqlerrm);
    end;
    --- Insertar relacion PRINCIPAL cliente cuentas
    for rel in rel_cta(r.nrocta) loop
      begin
        insert into ge_cta_clientes
          (cod_persona, nro_cuenta, dig_verificador,
           cod_oficina, cod_modulo, cod_modalidad, relacion)
        values
          (rel.cod_persona, v_nvo_cuenta, rel.dig_verificador,
           rel.cod_oficina, 15, 151, rel.relacion);
        v_cod_persona := rel.cod_persona;
      exception
        when others then
          raise_application_error(-20005,'Error al insertar en ge_cta_clientes:'||rel.cod_persona||' Cuenta:'||r.nrocta||' '||sqlerrm);
      end;
    end loop;

    --- Insertar relacion OTRAS cliente cuentas
    for rel_o in rel_cta_o(r.nrocta) loop
      begin
        insert into ge_cta_clientes
          (cod_persona, nro_cuenta, dig_verificador,
           cod_oficina, cod_modulo, cod_modalidad, relacion)
        values
          (rel_o.cod_persona, v_nvo_cuenta, rel_o.dig_verificador,
           rel_o.cod_oficina, 15, 151, rel_o.relacion);
       exception
         when others then
           raise_application_error(-20006,'Error al insertar otras Ctas. relacionadas. Cliente:'||rel_o.cod_persona||' Cuenta:'||r.nrocta||' '||sqlerrm);
       end;
    end loop;

    --- Insertar Garantias si las hubieran...
    for gr in gar(r.nrocta) loop
      begin
        insert into ov_cta_garantias
          (nro_cuenta, nro_garantia, cod_garantia,
           mto_aplicado, mto_apl_computable)
        values
          (v_nvo_cuenta, gr.nro_garantia, gr.cod_garantia,
           gr.mto_aplicado, gr.mto_apl_computable);
       exception
         when others then
           raise_application_error(-20007,'Error al insertar ov_cta_garantias, Garantia Nro.:'||gr.nro_garantia||' Cuenta:'||r.nrocta||' '||sqlerrm);
       end;
    end loop;

    -- genero el telegrama respectivo
    prv_gen_telegrama(r.nrocta,151,r.mtovencido,r.mtovencido,r.moneda,v_cod_persona);

    begin
      --Hacer un registro en Ge_Movimiento por la
      --Entrada de la cuenta a Operaciones Vencidas
      r_gmovi := null;
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      
        -- 26/06/2013-EC-CL : Cuando la secuencia llega a 997, vuelve a 1
         if v_nro_secuencia >= 997 then
            v_nro_secuencia :=1;
            v_hora :=  pag_gen.FU_OBT_SIG_SEGUNDO(v_hora); 
         end if;
        --
      --pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);

      r_gmovi.nro_secuencia      := v_nro_secuencia;
      r_gmovi.cod_usuario        := user;
      r_gmovi.hora               := v_hora;
      r_gmovi.fecha              := v_fcdehoy;
      r_gmovi.cod_modulo         := 15;
      r_gmovi.cod_modalidad      := 151;
      r_gmovi.cod_oficina        := r.oficina;
      r_gmovi.nro_cuenta         := v_nvo_cuenta;
      r_gmovi.cod_moneda         := r.moneda;
      r_gmovi.tip_mov_rubro      := 'C';
      r_gmovi.cod_tra_padre      := 358;
      r_gmovi.cod_transaccion    := 711;
      r_gmovi.monto              := r.mtovencido;
      r_gmovi.fec_valor          := v_fcdehoy;
      r_gmovi.emi_aviso          := 'S';
      r_gmovi.reversado          := 'N';
      r_gmovi.protegido          := 'N';
      r_gmovi.estado             := 'N';
      r_gmovi.cod_ofi_origen     := r.oficina;
      r_gmovi.cod_mod_padre      := 15;
      r_gmovi.cod_mad_padre      := 151;
      r_gmovi.nro_documento      := r.nrocta;
      r_gmovi.concepto           := 'Pasar a vencido la cta.='||r.nrocta;
      r_gmovi.est_cuenta         := v_cat_cuenta;
      
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    exception
     when others then
       raise_application_error(-20008,'Error al insertar movimiento de alta en Op. Vencidas. Cuenta:'||r.nrocta||' '||sqlerrm);
    end;
    -- Marcar Referencia del proceso finalizado si es que se pudo hacer
    update ta_mov_especiales_tmp
           set ref_proceso = 'PASE_PROCESADO - ' || to_char(sysdate, 'dd/mm/yyyy hh:mi:ss')
    where rowid = r.fila;

  end loop;

exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20009,'Error: En el proceso de deudas de tarjetas vencidas... '||sqlerrm);
    End if;
end;
/

