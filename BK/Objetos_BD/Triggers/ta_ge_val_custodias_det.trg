CREATE OR REPLACE TRIGGER IT.TA_GE_VAL_CUSTODIAS_DET
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_VAL_CUSTODIAS_DET
 FOR EACH ROW

DECLARE

    PROCEDURE PP_ALTA_VALOR IS
       v_hora            ge_movimientos.hora%type          := to_char(sysdate,'hh24:mi:ss');
       v_fecha           ge_movimientos.fecha%type         := pag_cal.fu_obt_fec_actual(1);
       v_nro_secuencia   ge_movimientos.nro_secuencia%type := 1;
       v_oficina         ge_movimientos.cod_oficina%type   := fug_obt_ofi_usuario(user);
       v_cod_persona     ge_movimientos.cod_persona%type;
       r_gmovi           ge_movimientos%rowtype;
       v_cod_moneda      ge_val_custodias.cod_moneda%type;
       v_val_nominal     ge_val_custodias.val_nominal%type;

    BEGIN
         --Datos de la cabecera del documento
         Begin
            Select a.cod_moneda, a.val_nominal
              into v_cod_moneda, v_val_nominal
              From ge_val_custodias a
             where a.cod_val_custodia = :new.cod_val_custodia;
         Exception
            When Others Then
                 raise_application_error(-20000,'Error al Obtener datos de cabecera '||sqlerrm);
         End;
         --Datos de Vinculos a documentos
         Begin
            Select a.cod_persona
              into v_cod_persona
              from ge_val_cus_titulares a
             where a.cod_val_custodia = :new.cod_val_custodia
               and a.nro_secuencia    = :new.nro_secuencia
               and a.relacion         = 'P';
         Exception
            When Others Then
                 raise_application_error(-20000,'Error al Obtener vinculos del documento '||sqlerrm);
         End;
         r_gmovi.cod_usuario       := user;
         r_gmovi.hora              := v_hora;
         r_gmovi.fecha             := v_fecha;
         r_gmovi.nro_secuencia     := v_nro_secuencia;
         r_gmovi.cod_modulo        := 1;
         r_gmovi.cod_modalidad     := 1;
         r_gmovi.cod_oficina       := v_oficina;
         r_gmovi.nro_cuenta        := NULL;
         r_gmovi.cod_moneda        := v_cod_moneda;
         r_gmovi.fec_valor         := v_fecha;
         r_gmovi.cod_tra_padre     := 3160;
         r_gmovi.cod_mod_padre     := 1;
         r_gmovi.cod_mad_padre     := 1;
         r_gmovi.cod_transaccion   := 3161;
         r_gmovi.monto             := :new.cantidad * v_val_nominal;
         r_gmovi.nro_documento     := :new.cod_val_custodia;
         r_gmovi.nro_documento2    := null;
         r_gmovi.cod_ofi_origen    := v_oficina;
         r_gmovi.emi_aviso         := 'N';
         r_gmovi.concepto          := 'Reint.Doc.Custodia '||:new.cod_val_custodia;
         r_gmovi.estado            := 'N';
         r_gmovi.reversado         := 'N';
         r_gmovi.cod_rubro         := null;
         r_gmovi.cod_tasa          := null;
         r_gmovi.val_tasa          := null;
         r_gmovi.tip_mov_rubro     := null;
         r_gmovi.cod_persona       := v_cod_persona;
         r_gmovi.referencia        := null;
         r_gmovi.fec_fin_retencion := null;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
    EXCEPTION
        when others then
             raise_application_error(-20000,'Error al Insertar Movimiento de Reintegro a Custodia '||sqlerrm);
    END;

    PROCEDURE PP_BAJA_VALOR IS
       v_hora            ge_movimientos.hora%type          := to_char(sysdate,'hh24:mi:ss');
       v_fecha           ge_movimientos.fecha%type         := pag_cal.fu_obt_fec_actual(1);
       v_nro_secuencia   ge_movimientos.nro_secuencia%type := 1;
       v_oficina         ge_movimientos.cod_oficina%type   := fug_obt_ofi_usuario(user);
       v_cod_persona     ge_movimientos.cod_persona%type;
       r_gmovi           ge_movimientos%rowtype;
       v_cod_moneda      ge_val_custodias.cod_moneda%type;
       v_val_nominal     ge_val_custodias.val_nominal%type;

    BEGIN
         --Datos de la cabecera del documento
         Begin
            Select a.cod_moneda, a.val_nominal
              into v_cod_moneda, v_val_nominal
              From ge_val_custodias a
             where a.cod_val_custodia = :new.cod_val_custodia;
         Exception
            When Others Then
                 raise_application_error(-20000,'Error al Obtener datos de cabecera '||sqlerrm);
         End;
         --Datos de Vinculos a documentos
         Begin
            Select a.cod_persona
              into v_cod_persona
              from ge_val_cus_titulares a
             where a.cod_val_custodia = :new.cod_val_custodia
               and a.nro_secuencia    = :new.nro_secuencia
               and a.relacion         = 'P';
         Exception
            When Others Then
                 raise_application_error(-20000,'Error al Obtener vinculos del documento '||sqlerrm);
         End;
         r_gmovi.cod_usuario       := user;
         r_gmovi.hora              := v_hora;
         r_gmovi.fecha             := v_fecha;
         r_gmovi.nro_secuencia     := v_nro_secuencia;
         r_gmovi.cod_modulo        := 1;
         r_gmovi.cod_modalidad     := 1;
         r_gmovi.cod_oficina       := v_oficina;
         r_gmovi.nro_cuenta        := NULL;
         r_gmovi.cod_moneda        := v_cod_moneda;
         r_gmovi.fec_valor         := v_fecha;
         r_gmovi.cod_tra_padre     := 3160;
         r_gmovi.cod_mod_padre     := 1;
         r_gmovi.cod_mad_padre     := 1;
         r_gmovi.cod_transaccion   := 3162;
         r_gmovi.monto             := :new.cantidad * v_val_nominal;
         r_gmovi.nro_documento     := :new.cod_val_custodia;
         r_gmovi.nro_documento2    := null;
         r_gmovi.cod_ofi_origen    := v_oficina;
         r_gmovi.emi_aviso         := 'N';
         r_gmovi.concepto          := 'Baja Temp.Doc.Custodia '||:new.cod_val_custodia;
         r_gmovi.estado            := 'N';
         r_gmovi.reversado         := 'N';
         r_gmovi.cod_rubro         := null;
         r_gmovi.cod_tasa          := null;
         r_gmovi.val_tasa          := null;
         r_gmovi.tip_mov_rubro     := null;
         r_gmovi.cod_persona       := v_cod_persona;
         r_gmovi.referencia        := null;
         r_gmovi.fec_fin_retencion := null;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
    EXCEPTION
        when others then
             raise_application_error(-20000,'Error al Insertar Movimiento de Baja Temporal '||sqlerrm);
    END;
BEGIN
  If updating  Then
     If :new.en_custodia <> :old.en_custodia and :old.cod_banco = :new.cod_banco and :old.cod_banco = 7 Then
        If :new.en_custodia    = 'N' Then
            PP_BAJA_VALOR;
        Elsif :new.en_custodia = 'S' Then
            PP_ALTA_VALOR;
        End IF;
     ElsIf :old.cod_banco <> :new.cod_banco and :new.en_custodia = :old.en_custodia and :old.en_custodia = 'S' Then
        If :new.cod_banco   <> 7 and :old.cod_banco = 7 Then
            PP_BAJA_VALOR;
        Elsif :new.cod_banco = 7 Then
            PP_ALTA_VALOR;
        End IF;
     End If;
  End If;

END;
/

