CREATE OR REPLACE PROCEDURE IT.prg_caj_chq_wf(p_nro_lote CJ_DEP_CHQ_ATM_REG.COD_LOTE%type, --varchar2(20)
                                                p_cod_persona ba_personas.cod_persona%type, --varchar2(10)
                                                p_nro_atm varchar2,
                                                p_tip_transaccion CJ_DEP_CHQ_ATM_REG.tip_transaccion%type, --varchar2(30)
                                                p_cod_respuesta out number,
                                                p_msj_respuesta out varchar2) IS
  v_cod_error number :=0;
  v_msj_error varchar2(200);
  v_can_chq number:= 0;
  v_fec varchar2(20);
  v_desc varchar2(10000);
  v_resp number;
  v_nro_solicitud cj_dep_chq_atm_reg.nro_solicitud%type;
  v_nombre varchar2(100);
  v_ci varchar2(100);
  v_destinatario ge_par_dinamicos.val_parametro%type;
  v_nro_transaccion CJ_DEP_CHQ_ATM_REG.Nro_Transaccion%type;
  v_nro_lote CJ_DEP_CHQ_ATM_REG.COD_LOTE%type;
  cursor dat is
     SELECT k.nro_cheque, K.MONTO_CHEQUE FROM it.CJ_DEP_CHQ_ATM_REG k where k.cod_lote = p_nro_lote;
  v_monto CJ_DEP_CHQ_ATM_REG.Monto_Cheque%type;

  v_nro_cuenta CJ_DEP_CHQ_ATM_REG.Nro_Cheque%type;
  v_nro_atm CJ_DEP_CHQ_ATM_REG.Atm_Id%type;
  v_nro_boleta CJ_LOG_ATM_CAJ.Nro_Transaccion%type;

  v_moneda varchar2(3);
  v_nro_cta CJ_DEP_CHQ_ATM_REG.Nro_cuenta%type;

BEGIN
  begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;

 --Validar los campos de entrada
  if p_cod_persona is null then
    v_cod_error := 1;
    v_msj_error := 'Nro. de persona no puede ser nulo';
  end if;
 if p_nro_atm is null then
    v_cod_error := 2;
    v_msj_error := 'Numero de ATM no puede ser nulo';
  end if;
   if p_tip_transaccion is null then
    v_cod_error := 3;
    v_msj_error := 'Tipo de transaccion no puede ser nulo';
   else
    if p_tip_transaccion not in ('deposito_che_clie','deposito_che_no_clie','entrega_che_clie','entrega_che_no_clie') then
       v_cod_error := 4;
       v_msj_error := 'Tipo de transaccion no corresponde.';
    end if;
  end if;
   if p_nro_lote is null then
    v_cod_error := 5;
    v_msj_error := 'Numero de transaccion no puede ser nulo';
  end if;
   --Recupera el nro de lote a partir del nro de transaccion (p_nro_lote)
   BEGIN
     SELECT distinct cod_lote
       into v_nro_lote
       FROM CJ_DEP_CHQ_ATM_REG cdc
      WHERE cdc.cod_persona = p_cod_persona
        AND cdc.nro_transaccion = p_nro_lote --nro_transaccion
        AND cdc.TIP_TRANSACCION = p_tip_transaccion;
    exception
      when others then
       v_cod_error := 6;
       v_msj_error := 'La consulta de cheques no ha devuelto nro_transaccion.SqlErr:'||substr(sqlerrm, 70);
    end;
   --Cantidad de registros
   BEGIN
     SELECT count(*)
       into v_can_chq
       FROM CJ_DEP_CHQ_ATM_REG cdc
      WHERE cdc.cod_persona = p_cod_persona
        AND cdc.cod_lote = v_nro_lote --cod_lote
        AND cdc.TIP_TRANSACCION = p_tip_transaccion;
    exception
      when others then
       v_cod_error := 6;
       v_msj_error := 'La consulta de cheques no ha devuelto datos.SqlErr:'||substr(sqlerrm, 70);
    end;
    --Se obtiene nro_solicitud p/Entrega de Cheques
    BEGIN
      if p_tip_transaccion in ('entrega_che_clie','entrega_che_no_clie') then
         SELECT cdc.nro_solicitud
           into v_nro_solicitud
           FROM CJ_DEP_CHQ_ATM_REG cdc
          WHERE cdc.cod_persona = p_cod_persona
            AND cdc.cod_lote = v_nro_lote--p_nro_lote
            AND cdc.TIp_TRANSACCION = p_tip_transaccion
            AND cdc.atm_id = p_nro_atm
            AND ROWNUM = 1
           group by cdc.nro_solicitud,cdc.fecha, cdc.nro_transaccion
           ORDER BY cdc.fecha DESC;
       else
         SELECT sum(cdc.monto_cheque), cdc.nro_cuenta, fug_obt_mon_cta(cdc.nro_cuenta)
           into v_monto , v_nro_cta, v_moneda
           FROM CJ_DEP_CHQ_ATM_REG cdc
          WHERE cdc.cod_persona = p_cod_persona
            AND cdc.cod_lote = v_nro_lote--p_nro_lote
            AND cdc.TIp_TRANSACCION = p_tip_transaccion
            AND cdc.atm_id = p_nro_atm
           group by cdc.cod_lote, cdc.nro_cuenta;
           --ORDER BY cdc.fecha DESC;

           BEGIN
              SELECT UNIQUE cjc.nro_cuenta as nro_cuenta, TO_NUMBER(REGEXP_REPLACE(cjc.atm_id, '[^0-9]')) as nro_atm, cjc.nro_transaccion
              INTO v_nro_cuenta, v_nro_atm , v_nro_transaccion
              FROM CJ_DEP_CHQ_ATM_REG cjc
              WHERE
              cjc.tip_transaccion = p_tip_transaccion
              AND cjc.atm_id = p_nro_atm AND cjc.cod_lote = p_nro_lote
              AND cjc.cod_persona = p_cod_persona
              AND ROWNUM = 1;

            exception
              when others THEN

                 v_nro_transaccion := 0;
          END;

        end if;
    exception
      when others then
       v_cod_error := 7;
       v_msj_error := 'Error en la consulta.SqlErr:'||substr(sqlerrm, 70);

    end;

   --Campos para el correo
     v_nombre:= fue_obt_nom_persona(p_cod_persona);
     v_ci:= fue_obt_nro_doc_persona(p_cod_persona);
     v_fec := to_char(sysdate, 'dd/mm/yyyy HH24:MI:SS');

       if p_tip_transaccion in ('entrega_che_clie','entrega_che_no_clie') then
             v_desc :='Fecha: '||v_fec ||chr(10)||chr(13)||
             'N. solicitud: '||v_nro_solicitud||chr(10)||chr(13)||
             'Nro. doc: '||v_ci||chr(10)||chr(13)||
             'Nombre: '||v_nombre||chr(10)||chr(13)||
             'Cant. cheque: '||v_can_chq||chr(10)||chr(13)||
             'Descripcion: '||'Cheques por operacion de descuento de cheques.'||chr(10)||chr(13)||
             'ATM:'||p_nro_atm||chr(10)||chr(13);
             --'N. Boleta:'||v_nro_transaccion||chr(10)||chr(13);
             for i in dat loop
               v_desc:= v_desc ||'Nro. Cheque:'||i.nro_cheque||chr(10)||chr(13);
             end loop;
       else
         if v_moneda = 'USD' then
             v_desc := p_nro_lote||chr(10)||chr(13)||' '||
             'Fecha: '||v_fec ||chr(10)||chr(13)||
             'N. Boleta:'||p_nro_lote||chr(10)||chr(13)||
             'Nro. doc: '||v_ci||chr(10)||chr(13)||
             'Nombre: '||v_nombre||chr(10)||chr(13)||
             'Cant. cheque: '||v_can_chq||chr(10)||chr(13)||
             'Nro Cuenta: '||v_nro_cta||chr(10)||chr(13)||
             'Moneda: '||v_moneda||chr(10)||chr(13)||
             'Monto Total: '||to_char(v_monto)||chr(10)||chr(13)||
             'Descripcion: '||'Depositos de Cheques via TEDs.'||chr(10)||chr(13)||
             'ATM:'||p_nro_atm||chr(10)||chr(13);
              for i in dat loop
               v_desc:= v_desc ||'Nro. Cheque: '||i.nro_cheque||chr(10);
               v_desc:= v_desc ||'Monto Cheque: '||to_char(i.monto_cheque)||chr(10)||chr(13);
             end loop;
           else
             v_desc := p_nro_lote||chr(10)||chr(13)||' '||
             'Fecha: '||v_fec ||chr(10)||chr(13)||
             'N. Boleta:'||p_nro_lote||chr(10)||chr(13)||
             'Nro. doc: '||v_ci||chr(10)||chr(13)||
             'Nombre: '||v_nombre||chr(10)||chr(13)||
             'Cant. cheque: '||v_can_chq||chr(10)||chr(13)||
             'Nro Cuenta: '||v_nro_cta||chr(10)||chr(13)||
             'Moneda: '||v_moneda||chr(10)||chr(13)||
             'Monto Total: '||v_monto||chr(10)||chr(13)||
             'Descripcion: '||'Depositos de Cheques via TEDs.'||chr(10)||chr(13)||
             'ATM:'||p_nro_atm||chr(10)||chr(13);
              for i in dat loop
               v_desc:= v_desc ||'Nro. Cheque: '||i.nro_cheque||chr(10);
               v_desc:= v_desc ||'Monto Cheque: '||i.monto_cheque||chr(10)||chr(13);
             end loop;
            end if;
         end if;
    --Genera el circuito
    begin
      v_desc:= substr(v_desc, 0, 999);
      if p_tip_transaccion in ('entrega_che_clie','entrega_che_no_clie') then
         v_resp := paw_cir.FU_INI_CIRCUITO(56, p_cod_persona, p_cod_persona, v_desc); --Cod_tip_circuito = 54--Descuento de CHQ
      else
         v_resp := paw_cir.FU_INI_CIRCUITO(55, p_nro_lote, p_cod_persona, v_desc); --Cod_tip_circuito = 55--Deposito de CHQ
      end if;
    exception
      when others then
        v_cod_error := 8;
       v_msj_error := 'No se ha podido crear la tarea.Verificar datos de entrada.SqlErr:'||substr(sqlerrm, 70);
    end;

    if v_resp = 0 then
          --Enviar notificacion al correo configurado
       if p_tip_transaccion in ('entrega_che_clie','entrega_che_no_clie') then
        --Obtener destinatario configurado
        v_destinatario:= fug_obt_pardinamico('MAI_DESC_CHEQUE'); --operaciones@ueno.com.py
        it_mail.mail(fug_obt_dir_correo,
                       v_destinatario,
                       'Verificacion de Operacion en TED por Descuento de Cheques',
                       v_desc);
      else
        --Obtener destinatario configurado
        v_destinatario:= fug_obt_pardinamico('MAI_DEP_CHEQUE'); --operaciones@ueno.com.py
        it_mail.mail(fug_obt_dir_correo,
                       v_destinatario,
                       'Verificacion de Operacion en TED por Deposito de Cheques',
                       v_desc);
        end if;
    end if;

  if nvl(v_cod_error, 0) != 0 then
    p_cod_respuesta := v_cod_error;
    p_msj_respuesta := v_msj_error;
  else
    p_cod_respuesta := 0;
    p_msj_respuesta := 'OK';
  end if;

EXCEPTION
  when others then
    NULL;
END;
/
