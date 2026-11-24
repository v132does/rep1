CREATE OR REPLACE PACKAGE BODY IT.PAC_CHE IS

/* Generar Chequera */
PROCEDURE PR_INS_CC_CHEQUERA
 (RP_CSCHE IN CC_CHEQUERAS%ROWTYPE
 )
 IS
BEGIN
   insert into cc_chequeras
   (nro_cuenta      , serie         , nro_che_inicial   , nro_che_final,
    can_cheques     , estado        , fec_cam_estado    , ult_che_emitido,
    usu_insercion   , fec_insercion , usu_modificacion  , fec_modificacion,
    est_cheques     , tipo          , fec_solicitud     ,  hor_solicitud,
    cod_usuario     , cod_ofi_retiro, cod_gru_envio)
    values
    (rp_csche.nro_cuenta      , rp_csche.serie         , rp_csche.nro_che_inicial   , rp_csche.nro_che_final,
    rp_csche.can_cheques     , rp_csche.estado        , rp_csche.fec_cam_estado    , rp_csche.ult_che_emitido,
    rp_csche.usu_insercion   , rp_csche.fec_insercion , rp_csche.usu_modificacion  , rp_csche.fec_modificacion,
    rp_csche.est_cheques     , rp_csche.tipo          , rp_csche.fec_solicitud     , rp_csche.hor_solicitud,
    rp_csche.cod_usuario     , rp_csche.cod_ofi_retiro, rp_csche.cod_gru_envio);
exception
    when others then
        raise_application_error(-20000,'Error al insertar cc_chequera PR_INS_CC_CHEQUERA '||sqlerrm);

END;
/* Obtener la cantidad por estado de cheque */
FUNCTION FU_OBT_CAN_EST_CHE
 (P_ESTADO IN CC_CHEQUERAS.ESTADO%TYPE
 ,P_EST_CHEQUES IN CC_CHEQUERAS.EST_CHEQUES%TYPE
 )
 RETURN NUMBER
 IS

V_POS NUMBER(4);
Begin
    For pos in 1..length(p_est_cheques) loop
      If substr(p_est_cheques,pos,1) = p_estado then
         v_pos := nvl(v_pos,0) + 1;
      End if;
    End loop;
    return v_pos;
End;
/* Pasar el cheque a un estado */
FUNCTION FU_CON_CAM_EST_CHE
 (P_CUENTA IN VARCHAR2     -- ENTRADA: numero de cuenta del cheque
 ,P_CHEQUE IN NUMBER       --          nro de cheque
 ,P_ESTADO IN VARCHAR2     --          estado al que se quiere pasar
 ,P_IMPORTE IN NUMBER      --          importe si existe
 ,P_CHEQUE_INI OUT NUMBER  -- SALIDA:  Nro de cheque inicial de la chequera
 ,P_ERROR OUT VARCHAR2     --          Descripcion del error, si existe
 ,P_CUENTA_CERT OUT VARCHAR2 --          Nro de la cuenta certificado, si es 'C'
 ,P_SERIE IN CC_CHEQUERAS.SERIE%type default null --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
 )
 RETURN VARCHAR2
 IS

V_ESTADO VARCHAR2(1);
V_POSCHEQUE NUMBER(8);
V_DUMMY VARCHAR2(50);
V_EST_CHEQ VARCHAR2(1);
V_CHE_INICIAL NUMBER(8);
V_CAN_CHEQUES NUMBER(5);
V_EST_CHEQUES VARCHAR2(1000);
v_existe varchar2(1) := 'N';
cursor cur_cheque IS
   SELECT estado,nro_che_inicial,can_cheques,est_cheques
     FROM  cc_chequeras
    WHERE nro_cuenta = p_cuenta
      AND p_cheque >= nro_che_inicial
      AND p_cheque <  nro_che_inicial + can_cheques
      AND p_cheque between nro_che_inicial and nro_che_final
      AND (serie = nvl(P_SERIE,serie) or serie is null) --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
   ORDER BY fec_solicitud desc;
   cursor es_gerencial is
     select 'S'
       from ge_cuentas
      where nro_cuenta = p_cuenta
        and cod_modalidad in (43,45);
   cursor cheq_gerencial is
     select nro_referencia cuenta_ref,monto valor, rowid
     from cc_che_ger_emitidos
     where nro_cheque = p_cheque
     and   nro_cuenta = p_cuenta;
   cursor cheq_certificado is
     select nro_cta_certificado cuenta_ref,monto valor, rowid
     from cc_che_certificados
     where nro_cheque = p_cheque
     and   nro_cuenta = p_cuenta;
   cursor cheq_onp is
     select rowid
     from cc_che_ord_no_pagos
     where nro_cheque = p_cheque
     and   nro_cuenta = p_cuenta;

  c1 cheq_gerencial%rowtype;
begin
    p_error := '';
    if nvl(p_importe,0) <= 0 and p_estado = 'P' then
      p_error := 'El importe '||to_char(p_importe)||' del cheque '||to_char(p_cheque) ||' es INCORRECTO ';
      return null;
    end if;
    if p_estado not in ('S','E','C','O','P','G','A') then
      p_error := 'Estado invalido para el Cheque '||to_char(p_cheque)||' cuenta '||p_cuenta;
      return(null);
    end if;
    open cur_cheque;
    fetch cur_cheque into v_est_cheq,v_che_inicial,v_can_cheques,v_est_cheques;
    close cur_cheque;
    if v_est_cheq is null then
      p_error := '1 Cheque '||to_char(p_cheque)||' Inexistente para la cuenta '||p_cuenta;
      return(null);
    end if;
    --Posicion del cheque evaluado sc_etche+v_poscheq
    v_poscheque := p_cheque-v_che_inicial+1 ;
    v_estado := substr(v_est_cheques,v_poscheque,1);
    if v_estado not in ('S','E','C','O','P','G','A') then
      p_error := 'Estado '||v_estado||' es incorrecto para el Cheque '||to_char(p_cheque)||' cuenta '||p_cuenta;
      return(null);
    end if;
    --La chequera debe haberse entregado
    if v_est_cheq != 'E' and p_estado != 'S' then
    -- if c.est_chequera != 'C' then
      p_error := 'La chequera del cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no ha sido Entregada';
    --El cheque esta anulado nada que hacer
    elsif v_estado = 'A' then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' ha sido anulado';
    --El cheque esta pagado nada que hacer solo Reversar
    elsif v_estado = 'P' then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' ya fue pagado';
    --El cheque esta solicitado solo puede pasar a E(ntregado)
    elsif v_estado = 'S' and p_estado  in ('C','G','P','O') then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no se ha Entregado';
    --El cheque esta O.N.P nada que hacer Solo Reversar
    elsif v_estado = 'O'  then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' tiene Orden de NO Pagar';
    --El cheque no puede regresar a Solicitado solo Reversando
    elsif v_estado = 'E' and p_estado = 'S' then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' ya ha sido entregado';
    --El cheque esta certificado no puede regresar a estados anteriores solo Reversando
    elsif v_estado = 'C' and p_estado in ('G','S') then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' es Certificado';
    --El cheque esta Gerencial no puede regresar a estados anteriores solo Reversando
    --elsif v_estado = 'G' and p_estado in ('C','E','S') then
    -- Debe permitir volver a Emitido si aun no se imprimio o proceso
    elsif v_estado = 'G' and p_estado in ('C','S') then
      p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' es Gerencial';
    --Verificar si es un cheque con pagos parciales
    elsif v_estado = 'E' and nvl(p_estado,'X') <> 'P' then 
      begin
        select 'S'
          into v_existe
          from cc_che_tra_multiples 
          where nro_cheque = p_cheque
            and nro_cuenta = p_cuenta;
      exception
         when no_data_found then
           v_existe := 'N';
      End;
      If v_existe = 'S' then
        p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' tiene pagos parciales';
      end if;
    elsif v_estado = 'C' then
       open cheq_certificado;
       fetch cheq_certificado into c1;
      if cheq_certificado%notfound then
         p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no existe en cc_che_certificados';
      end if;      
       close cheq_certificado;

    elsif v_estado = 'G' then
      open es_gerencial;
      fetch es_gerencial into v_dummy;
      close es_gerencial;
      if v_dummy = 'S' then
        open cheq_gerencial;
        fetch cheq_gerencial into c1;
        if cheq_gerencial%notfound then
          p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no existe en cc_che_ger_emitidos';
        end if;
        close cheq_gerencial;
       else
        p_error := 'Cta.Gerencia no definida en parametros';
       end if;
    end if;
    if p_error is null then
      if p_estado = 'O' then
        open cheq_onp;
        fetch cheq_onp into v_dummy;
        close cheq_onp;
        if v_dummy is null then
          p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no existe en cc_che_ord_no_pagos';
        end if;
      /*elsif p_estado = 'G' then
        open cheq_gerencial;
        fetch cheq_gerencial into c1;
        if cheq_gerencial%notfound then
          p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no existe en cc_che_ger_emitidos';
        end if;
        close cheq_gerencial;*/
      elsif p_estado = 'C' then
         open cheq_certificado;
         fetch cheq_certificado into c1;
        if cheq_certificado%notfound then
           p_error := 'El cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no existe en cc_che_certificados';
        end if;
         close cheq_certificado;
      elsif p_estado = 'P' then
        if v_estado = 'G' then
          if nvl(c1.valor,0) <> p_importe then
            p_error := 'El monto del cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no coincide con la emision';
          end if;
        elsif v_estado = 'E' then
          open es_gerencial;
          fetch es_gerencial into v_dummy;
          close es_gerencial;
          if v_dummy = 'S' then
            p_error := 'El cheque de gerencia '||to_char(p_cheque)||' cuenta '||p_cuenta||' no ha sido emitido';
          end if;
         elsif v_estado = 'C' then
           if nvl(c1.valor,0) <> p_importe then
            p_error := 'El monto del cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' no coincide con el Certificado';
           end if;
          if p_error is null then
            p_cuenta_cert  := c1.cuenta_ref;
          end if;
         end if;
      end if;
    end if;
    p_cheque_ini := v_che_inicial;
    return(v_estado);
  exception
    when others then
      p_error := 'Error en chequera: '||sqlerrm;
      raise_application_error(-20001,p_error);
  end;
/* Actualiza el estado del cheque de cc_chequeras */
FUNCTION FU_ACT_CHEQUE
 (P_CUENTA     IN VARCHAR2
 ,P_CHEQUE     IN NUMBER
 ,P_ESTADO     IN VARCHAR2
 ,P_CHEQUE_INI IN NUMBER DEFAULT NULL
 ,P_IMPORTE    IN CC_CHE_GER_EMITIDOS.MONTO%TYPE DEFAULT NULL
 ,P_USUARIO    IN CC_CHE_GER_EMITIDOS.COD_USUARIO%TYPE DEFAULT NULL
 ,P_FECHA      IN DATE DEFAULT NULL
 ,P_HORA       IN CC_CHE_PAGADOS.HORA%TYPE DEFAULT NULL
 ,P_CAJA       IN CC_CHE_PAGADOS.NRO_CAJA%TYPE DEFAULT NULL
 ,P_BANCO      IN CC_CHE_PAGADOS.COD_BANCO%TYPE DEFAULT NULL
 ,P_TRAN       IN CC_CHE_PAGADOS.COD_TRANSACCION%TYPE DEFAULT NULL
 ,P_MONEDA     IN CC_CHE_PAGADOS.COD_MONEDA%TYPE DEFAULT NULL
 ,P_OFICINA    IN CC_CHE_PAGADOS.COD_OFI_ORIGEN%TYPE DEFAULT NULL
 ,P_MODULO     IN CC_CHE_PAGADOS.COD_MODULO%TYPE DEFAULT NULL
 ,P_MODALIDAD  IN CC_CHE_PAGADOS.COD_MODALIDAD%TYPE DEFAULT NULL
 ,P_SERIE      IN CC_CHEQUERAS.SERIE%type default null --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
 )
 RETURN VARCHAR2
 IS

--Datos del cheque (pago parcial)
v_existe          varchar2(1) := 'N';
v_existe_che_pagado varchar2(1) := 'N';
v_monto           cc_che_tra_multiples.monto%type;
v_mto_utilizado   cc_che_tra_multiples.mto_utilizado%type;
--
V_POSCHEQUE       number;
V_RESULT          varchar2(1000);
v_nro_che_inicial number(10) := p_cheque_ini;
v_est_anterior    varchar2(1);
/*AP 2299 se agrega v_serie*/
v_serie cc_chequeras.serie%type;

begin

 if p_cheque_ini is null then
   -- busco el numero inicial del cheque
   if p_serie is null then --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
      begin
        SELECT nro_che_inicial, serie
          into v_nro_che_inicial, v_serie
          FROM cc_chequeras
         WHERE nro_cuenta = p_cuenta
           AND p_cheque >= nro_che_inicial
           AND p_cheque <  nro_che_inicial + can_cheques
           AND p_cheque between nro_che_inicial and nro_che_final
           AND fec_solicitud = (SELECT max(fec_solicitud)
                                  FROM  cc_chequeras
                                 WHERE nro_cuenta = p_cuenta
                                   AND p_cheque >= nro_che_inicial
                                   AND p_cheque <  nro_che_inicial + can_cheques
                                   AND p_cheque between nro_che_inicial and nro_che_final);
      exception
        when others then
          raise_application_error(-20000,'Error al leer chequeras para el cheque '||to_char(p_cheque)||' y Cuenta '||p_cuenta||'-'||sqlerrm);
      end;
   else --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
      begin
        SELECT nro_che_inicial, serie
          into v_nro_che_inicial, v_serie
          FROM cc_chequeras
         WHERE nro_cuenta = p_cuenta
           AND p_cheque >= nro_che_inicial
           AND p_cheque <  nro_che_inicial + can_cheques
           AND p_cheque between nro_che_inicial and nro_che_final
           AND (serie = nvl(P_SERIE,serie) or serie is null);
      exception
        when others then
          raise_application_error(-20202,'Error al leer chequeras para el cheque '||to_char(p_cheque)||' y Cuenta '||p_cuenta||'-'||sqlerrm);
      end;      
   end if;
 end if;
 v_poscheque := p_cheque - v_nro_che_inicial + 1;
 if p_estado is not null then
   --Verificar si es un cheque con pagos parciales
   begin
     select 'S',monto,mto_utilizado
       into v_existe, v_monto,v_mto_utilizado
       from cc_che_tra_multiples
      where nro_cuenta = p_cuenta
        and nro_cheque = p_cheque;
   exception
     when no_data_found then
       v_existe := 'N';
   end;
   --verificamos si ya existe un registro en cc_che_pagados
   begin
     select 'S'
     into v_existe_che_pagado
       from cc_che_pagados a
       where a.nro_cuenta = p_cuenta
       and a.nro_cheque = p_cheque
       and a.fecha = p_fecha;
     exception
       when no_data_found then
            v_existe_che_pagado := 'N';
   end;
   If nvl(p_estado,'X') = 'P' then
     If v_existe = 'S' then --Es un cheque con pagos parciales
       --Verificar si todavia no se utilizo todo el monto del cheque
       If nvl(v_mto_utilizado,0) < v_monto  then
         If p_importe > (v_monto - nvl(v_mto_utilizado,0)) then
           v_result := 'ERROR. Monto supera al saldo del cheque  - cuenta '||p_cuenta||' cheque '||to_char(p_cheque);
         else
           --Actualiza el monto utilizado
           update cc_che_tra_multiples
              set mto_utilizado = nvl(mto_utilizado,0) + p_importe
            where nro_cuenta = p_cuenta
              and nro_cheque = p_cheque;
           --Si el monto utilizado es igual al monto de cheque, se actualiza estado = (P)agado
           If v_monto = p_importe+nvl(v_mto_utilizado,0) then
             UPDATE cc_chequeras
                set est_cheques = substr(est_cheques,1,v_poscheque-1)||p_estado||substr(est_cheques,v_poscheque+1,length(est_cheques))
              where nro_cuenta = p_cuenta
               and nro_che_inicial = v_nro_che_inicial;
           End if;
         End if;
       else
         --No se tiene que dar, porque al pagar todo, es que ya fue totalmente pagado
         v_result := 'ERROR. Cheque utilizado totalmente - cuenta '||p_cuenta||' cheque '||to_char(p_cheque);
       end if;
     else
       UPDATE cc_chequeras
          set est_cheques = substr(est_cheques,1,v_poscheque-1)||p_estado||substr(est_cheques,v_poscheque+1,length(est_cheques))
        where nro_cuenta = p_cuenta
          and nro_che_inicial = v_nro_che_inicial;
       if sql%notfound  then
         v_result := 'ERROR. Actualizando CC_CHEQUERAS cuenta '||p_cuenta||' cheque '||to_char(p_cheque)||'-'||sqlcode;
       end if;
     End if;
   else
     select substr(est_cheques,v_poscheque,1)
       into v_est_anterior
       from cc_chequeras
      where nro_cuenta =p_cuenta
        and nro_che_inicial = v_nro_che_inicial
    and (serie = v_serie OR v_serie is null);
     UPDATE cc_chequeras
        set est_cheques = substr(est_cheques,1,v_poscheque-1)||p_estado||substr(est_cheques,v_poscheque+1,length(est_cheques))
      where nro_cuenta = p_cuenta
        and nro_che_inicial = v_nro_che_inicial;
     if sql%notfound  then
       v_result := 'ERROR. Actualizando CC_CHEQUERAS cuenta '||p_cuenta||' cheque '||to_char(p_cheque)||'-'||sqlcode;
     end if;
   End if;
   If nvl(p_estado,'X') = 'P' and v_result is null then
     --Insertar datos del cheque en cc_che_pagados
     if nvl(v_existe_che_pagado,'N') <> 'S' then --si es cheque de pago parcial, ya existe en la tabla entonces, hacemos la actualizacion del monto
         begin
            insert into cc_che_pagados(nro_cuenta,nro_cheque,fecha,hora,cod_usuario,cod_moneda,monto,cod_modulo,cod_modalidad,cod_transaccion,nro_caja,cod_banco,cod_ofi_origen)
                   values(p_cuenta,p_cheque,p_fecha,p_hora,p_usuario,p_moneda,p_importe,p_modulo,p_modalidad,p_tran,p_caja,p_banco,p_oficina);
         exception
            when others then
               v_result := 'ERROR. Actualizando CC_CHE_PAGADOS cuenta '||p_cuenta||' cheque '||to_char(p_cheque)||'-'||sqlerrm;
         end;
      else
         begin
             update cc_che_pagados a
                    set a.monto = nvl(a.monto,0) + nvl(p_importe,0)
                    where a.nro_cuenta = p_cuenta
                    and a.nro_cheque = p_cheque
                    and a.fecha = p_fecha;
             exception
                    when others then
                      v_result := 'ERROR. Actualizando monto en CC_CHE_PAGADOS cuenta '||p_cuenta||' cheque '||to_char(p_cheque)||'-'||sqlerrm;
         end;
      end if;
     --Actualizar cheques devueltos a regularizado si corresponde
     begin
       update cc_che_devueltos
          set regularizado = 'S',
              fec_regularizacion = sysdate
        where nro_cuenta = p_cuenta
          and nro_cheque = p_cheque;
     exception
       when others then
         null;
     end;
   Elsif  nvl(p_estado,'X') in ('E','G','C') then
     -- borro el registro de los cheques pagados
     delete from cc_che_pagados
      where nro_cuenta = p_cuenta
        and nro_cheque = p_cheque
        and fecha = p_fecha
        and hora =  p_hora;
     --Actualizar cheques devueltos a NO regularizado si corresponde
     begin
       update cc_che_devueltos
          set regularizado = 'N',
              fec_modificacion = fec_modificacion
        where nro_cuenta = p_cuenta
          and nro_cheque = p_cheque;
     exception
       when others then
         null;
     end;        
     if p_estado = 'E' then  -- veo si estaba certificado
          if v_est_anterior = 'C' then   
            delete from cc_che_certificados
             where nro_cuenta = p_cuenta
               and nro_cheque = p_cheque
               and fec_pago is null;
            if sql%notfound then
               v_result := 'Cheque Certificado '||p_cheque||' no existe!!!';
            end if; 
          end if;  
     end if;              
   End if;
 end if;
 return v_result;
 EXCEPTION
   when others then
     v_result := 'ERROR. Actualizando CC_CHEQUERAS cuenta '||p_cuenta||' cheque '||to_char(p_cheque)||'-'||sqlerrm;
   return(v_result);
end;
/* Realiza el insert en el maestro de cheques gerenciales */
FUNCTION FU_INS_CHE_GER_EMI
 (P_CUENTA IN CC_CHE_GER_EMITIDOS.NRO_CUENTA%TYPE
 ,P_CHEQUE IN CC_CHE_GER_EMITIDOS.NRO_CHEQUE%TYPE
 ,P_IMPORTE IN CC_CHE_GER_EMITIDOS.MONTO%TYPE
 ,P_USUARIO IN CC_CHE_GER_EMITIDOS.COD_USUARIO%TYPE
 ,P_USU_PAG IN CC_CHE_GER_EMITIDOS.COD_USU_PAGADOR%TYPE
 ,P_FEC_EMIS IN CC_CHE_GER_EMITIDOS.FECHA%TYPE
 ,P_BENEFIC IN CC_CHE_GER_EMITIDOS.BENEFICIARIO%TYPE
 ,P_TIPO IN CC_CHE_GER_EMITIDOS.TIP_REFERENCIA%TYPE
 ,P_REFEREN IN CC_CHE_GER_EMITIDOS.NRO_REFERENCIA%TYPE
 ,P_FEC_PAGO IN CC_CHE_GER_EMITIDOS.FEC_PAGO%TYPE
 ,P_COD_MODULO IN CC_CHE_GER_EMITIDOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN CC_CHE_GER_EMITIDOS.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN CC_CHE_GER_EMITIDOS.COD_TRANSACCION%TYPE
 ,P_ESTADO IN GE_MOVIMIENTOS.ESTADO%TYPE DEFAULT NULL -- C.D.Fase III
 )
 RETURN VARCHAR2
 IS

V_ESTADO_ANT VARCHAR2(1);
V_RESULT VARCHAR2(1000);
V_CUENTA_CERT VARCHAR2(15);
begin
  insert into cc_che_ger_emitidos
    (nro_cheque,nro_cuenta,tip_referencia,monto,cod_usuario,cod_usu_pagador,fecha,beneficiario,
     nro_referencia,fec_pago, cod_modulo, cod_modalidad, cod_transaccion)
  values(p_cheque,p_cuenta,p_tipo,p_importe,p_usuario,p_usu_pag,p_fec_emis,p_benefic,
    p_referen,p_fec_pago, p_cod_modulo, p_cod_modalidad, p_cod_transaccion);
     /* Si se genera un Pedido de Autorizacion,no debe actualizar el estado 
       del Cheque(CC_CHEQUERAS), hasta que se Apruebe el Pedido. C.D.Fase III*/
      if p_estado <> 'P' then 
        v_estado_ant := FU_ACT_CAM_EST_CHE(p_cuenta,p_cheque,'G',v_result,v_cuenta_cert);
      end if;
    return v_result;
  exception
    when others then
       v_result := 'Error en inserta_cheque_gerencia '||sqlerrm;
       raise_application_error(-20004,v_result);
end;
FUNCTION FU_ACT_CAM_EST_CHE
 (P_CUENTA      IN VARCHAR2
 ,P_CHEQUE      IN NUMBER
 ,P_ESTADO_ACT  IN VARCHAR2
 ,P_ERROR       OUT VARCHAR2
 ,P_CUENTA_CERT OUT VARCHAR2
 )
 RETURN VARCHAR2
 IS

V_ESTADO_ANT VARCHAR2(1);
V_CHEQUE_INI NUMBER(8);
begin
  p_error :=  '';
  v_estado_ant := FU_CON_CAM_EST_CHE(p_cuenta,p_cheque,p_estado_act,0,v_cheque_ini,
  p_error,p_cuenta_cert);
  --Si se puede realizar el cambio en cc_chequeras
  if p_error is null then
    p_error := FU_ACT_CHEQUE(p_cuenta,p_cheque,p_estado_act,v_cheque_ini,null,null,null,null,null,null,null,null,null,null,null);
  end if;
  return v_estado_ant;
  exception
    when others then
       p_error := 'Error en cambio_estado_cheque '||sqlerrm;
       raise_application_error(-20002,p_error);
end;
/* Realiza el pago del cheque */
FUNCTION FU_ACT_PAG_CHE
 (P_CUENTA    IN CC_CHE_GER_EMITIDOS.NRO_CUENTA%TYPE
 ,P_CHEQUE    IN CC_CHE_GER_EMITIDOS.NRO_CHEQUE%TYPE
 ,P_IMPORTE   IN CC_CHE_GER_EMITIDOS.MONTO%TYPE
 ,P_USUARIO   IN CC_CHE_GER_EMITIDOS.COD_USUARIO%TYPE
 ,P_FECHA     IN DATE
 ,P_HORA      IN CC_CHE_PAGADOS.HORA%TYPE
 ,P_CAJA      IN CC_CHE_PAGADOS.NRO_CAJA%TYPE
 ,P_BANCO     IN CC_CHE_PAGADOS.COD_BANCO%TYPE
 ,P_TRAN      IN CC_CHE_PAGADOS.COD_TRANSACCION%TYPE
 ,P_MONEDA    IN CC_CHE_PAGADOS.COD_MONEDA%TYPE
 ,P_OFICINA   IN CC_CHE_PAGADOS.COD_OFI_ORIGEN%TYPE
 ,P_MODULO    IN CC_CHE_PAGADOS.COD_MODULO%TYPE
 ,P_MODALIDAD IN CC_CHE_PAGADOS.COD_MODALIDAD%TYPE
 ,P_SERIE     IN CC_CHEQUERAS.SERIE%type default null --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
 )
 RETURN VARCHAR2
 IS

V_RESULT VARCHAR2(2000);
V_ESTADO_ANT VARCHAR2(1);
V_CHEQUE_INI NUMBER(8);
V_MODUL_CERT NUMBER(3);
V_MODAL_CERT NUMBER(3);
V_OFICINA_CERT NUMBER(3);
V_CUENTA_CERT VARCHAR2(15);
begin
    v_estado_ant := FU_CON_CAM_EST_CHE(p_cuenta,p_cheque,'P', p_importe,v_cheque_ini,
    v_result,v_cuenta_cert,p_serie); --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
    if v_estado_ant = 'G' then
        UPDATE cc_che_ger_emitidos
        SET fec_pago = p_fecha,
            cod_usu_pagador = p_usuario
        WHERE nro_cheque = p_cheque
        and   nro_cuenta = p_cuenta;
        if sql%notfound then
          v_result := 'Cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' inexistente en el maestro cc_che_ger_emitidos';
        end if;
    elsif v_estado_ant = 'C'  then
      UPDATE cc_che_certificados
      SET fec_pago = p_fecha
        WHERE nro_cheque = p_cheque
        and   nro_cuenta = p_cuenta;
        if sql%notfound then
          v_result := 'Cheque '||to_char(p_cheque)||' cuenta '||p_cuenta||' inexistente en el maestro cc_che_certificados';
        end if;
    end if;
    --Si se puede realizar el cambio
    if v_result is null then
      v_result := FU_ACT_CHEQUE(p_cuenta,p_cheque,'P',v_cheque_ini,P_IMPORTE,P_USUARIO,P_FECHA,P_HORA,P_CAJA,P_BANCO,
                             P_TRAN,P_MONEDA,P_OFICINA,P_MODULO,P_MODALIDAD,P_SERIE); --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
    end if;
    return v_result;
  exception
    when others then
       v_result := 'Error en  pago_de_cheque '||sqlerrm;
       raise_application_error(-20003,v_result);
end;
/* reversar el pago de un cheque */
FUNCTION FU_REV_PAG_CHEQUE
 (P_CUENTA    IN CC_CHE_GER_EMITIDOS.NRO_CUENTA%TYPE
 ,P_CHEQUE    IN CC_CHE_GER_EMITIDOS.NRO_CHEQUE%TYPE
 ,P_MONTO     IN CC_CHE_GER_EMITIDOS.MONTO%TYPE DEFAULT null
 ,P_FECHA     IN CC_CHE_GER_EMITIDOS.FECHA%TYPE DEFAULT NULL 
 ,P_HORA      IN GE_MOVIMIENTOS.HORA%TYPE DEFAULT NULL
 )
 RETURN VARCHAR2
 IS

V_RESULT VARCHAR2(2000) := null;
V_EST_ACTUAL VARCHAR2(1);
V_EST_NUEVO  VARCHAR2(1) := 'E';
V_CHEQUE_INI NUMBER(8);
V_MODUL_CERT NUMBER(3);
V_MODAL_CERT NUMBER(3);
V_OFICINA_CERT NUMBER(3);
V_CUENTA_CERT VARCHAR2(15);
v_nro_cuenta varchar2(20) := p_cuenta;
v_fec_pago   date;
begin
    begin
      -- veo si es un cheque certificado
      select fec_pago, nro_cuenta
        into v_fec_pago, v_nro_cuenta
        from cc_che_certificados
       where nro_cheque = p_cheque
         and nro_cta_certificado = p_cuenta;
      if v_fec_pago is not null then
         v_est_nuevo := 'C';  -- vuelve a certificado
      end if;
    exception
       when no_data_found then
           v_nro_cuenta := p_cuenta;
       when too_many_rows then
           v_result := 'Cheque '||to_char(p_cheque)||' de la Cuenta '||p_cuenta||' esta duplicado en Cheques Certificados';
       when others then
           v_result := 'Cheque '||to_char(p_cheque)||' de la Cuenta '||p_cuenta||' con problema en Cheques Certificados-'||sqlerrm;
    end;
    if v_result is null then
      -- Recupero el estado actual del cheque
      v_est_actual := pac_che.fu_obt_est_che(v_nro_cuenta,
                                             p_cheque,
                                             v_result);
    end if;
    if v_result is null then
       -- no hay errores en la busqueda, se puede continuar
       if v_est_actual <> 'P' and v_est_nuevo <> 'C' then
          --Actualizar el mto utilizado si es cheque con pagos parciales
          Update cc_che_tra_multiples
             set mto_utilizado = nvl(mto_utilizado,0) - p_monto
           where nro_cheque = p_cheque
             and nro_cuenta = v_nro_cuenta;
          If sql%notfound then  
            v_result := 'Cheque '||to_char(p_cheque)||' de la Cuenta '||v_nro_cuenta||' no esta registrado como pagado';
          End if;
       else
          --Actualizar el mto utilizado si es cheque con pagos parciales
          Update cc_che_tra_multiples
             set mto_utilizado = nvl(mto_utilizado,0) - p_monto
           where nro_cheque = p_cheque
             and nro_cuenta = v_nro_cuenta;
       end if;
       if v_est_nuevo = 'C' then
          -- cheque certificado
          update cc_che_certificados
             set fec_pago = null
           WHERE nro_cheque = p_cheque
             and nro_cuenta = v_nro_cuenta;
          if sql%notfound then
             v_result := 'Cheque Certificado '||to_char(p_cheque)||' de la Cuenta '||v_nro_cuenta||' no se pudo actualizar';
          end if;
       else
          -- veo si es un cheque gerencia
          update cc_che_ger_emitidos
             set fec_pago = null,
                 cod_usu_pagador = null
           WHERE nro_cheque = p_cheque
             and nro_cuenta = p_cuenta;
          if sql%found then
             v_est_nuevo := 'G'; -- el estado es cheque gerencia
          end if;
       end if;
       --Si se puede realizar el cambio
       if v_result is null then
          v_result := FU_ACT_CHEQUE(v_nro_cuenta,
                                    p_cheque,
                                    v_est_nuevo,
                                    null,
                                    p_monto,
                                    null,
                                    p_fecha,
                                    p_hora);
       end if;
    end if;
    return v_result;
  exception
    when others then
       v_result := 'Error en  pago_de_cheque '||sqlerrm;
       raise_application_error(-20003,v_result);
end;
/* Obtiene el siguiente numero de cheque */
FUNCTION FU_OBT_SIG_NRO_CHE
 (P_CUENTA IN CC_CHEQUERAS.NRO_CUENTA%TYPE
 ,P_NRO_CHE_INICIAL IN CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE
 )
 RETURN NUMBER
 IS

V_CHEQUE NUMBER(8);
v_cheque_ini number(8);

cursor cheque is
select min(nvl(ult_che_emitido,nro_che_inicial-1))
    from cc_chequeras
   where nro_cuenta = p_cuenta
     and nro_che_inicial = nvl(p_nro_che_inicial,nro_che_inicial)
     and estado = 'E'
     and nvl(ult_che_emitido,0) < nro_che_final;
begin
  open cheque;
  fetch cheque into v_cheque;
  close cheque;
  if v_cheque is not null then
    v_cheque := v_cheque + 1;
    If P_NRO_CHE_INICIAL is not null then
      update cc_chequeras
         set ult_che_emitido = v_cheque
      where nro_cuenta = p_cuenta
        and nro_che_inicial = p_nro_che_inicial;
    else
      SELECT nro_che_inicial
        into v_cheque_ini
        FROM  cc_chequeras
       WHERE nro_cuenta = p_cuenta
         AND v_cheque >= nro_che_inicial
         AND v_cheque <  nro_che_inicial + can_cheques
         AND v_cheque between nro_che_inicial and nro_che_final;
      If v_cheque_ini is not null then
        select min(nvl(ult_che_emitido,nro_che_inicial-1))
          into v_cheque
          from cc_chequeras
         where nro_cuenta = p_cuenta
           and nro_che_inicial = v_cheque_ini
           and estado = 'E'
           and nvl(ult_che_emitido,0) < nro_che_final;
         v_cheque := v_cheque + 1;

        update cc_chequeras
           set ult_che_emitido = v_cheque
        where nro_cuenta = p_cuenta
          and nro_che_inicial = v_cheque_ini;
      End if;
    End if;
  end if;
  return (v_cheque);
  exception
    when others then
      raise_application_error(-20009,'Error sig. nro cheque '||sqlerrm);
end;
/* Obtener el rubro contable de la cuenta bancaria */
FUNCTION FU_OBT_RUB_CTA_BAN
 (P_CUENTA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS

V_RUBRO VARCHAR2(15);
BEGIN
  select cod_rubro
    into v_rubro
    from cc_cta_bancarias
   where nro_cuenta = p_cuenta;
  return (v_rubro);
  exception
    when others then
      raise_application_error(-20000,'Rec. rubro '||sqlerrm);
end;
/* Actualizar cheque emitido a impreso. */
PROCEDURE PR_ACT_IMP_CHE_EMI
 (P_NRO_CUENTA IN CC_CHE_GER_EMITIDOS.NRO_CUENTA%TYPE
 ,P_NRO_CHEQUE IN CC_CHE_GER_EMITIDOS.NRO_CHEQUE%TYPE
 ,P_IMPRESO IN CC_CHE_GER_EMITIDOS.IMPRESO%TYPE
 )
 IS
BEGIN
   update cc_che_ger_emitidos
      set impreso = p_impreso
    where nro_cuenta = p_nro_cuenta
      and nro_cheque = p_nro_cheque;
END;
PROCEDURE PR_OBT_SIG_NRO_CHE
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TIP_CHEQUERA IN CC_TIP_CHEQUERAS.COD_TIP_CHEQUERA%TYPE
 ,P_CANTIDAD IN CC_SOL_CHEQUERAS.CANTIDAD%TYPE
 ,P_CHEQUE_INICIAL OUT CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE
 ,P_CHEQUE_FINAL OUT CC_CHEQUERAS.NRO_CHE_FINAL%TYPE
 ,P_SERIE OUT CC_CHEQUERAS.SERIE%TYPE
 )
 IS
    v_sig_nro_cheque cc_chequeras.nro_che_inicial%type;
    v_serie          cc_chequeras.serie%type;
    v_fila           varchar2(100);
    v_lon_ser_cheque     number := fug_obt_pardinamico('LON_SER_CHEQUE');
    v_lon_sig_nro_che    number := fug_obt_pardinamico('LON_SIG_NRO_CHE');
    
BEGIN
  --No debo liberar el registro hasta que el usuario que lo esta utilizando haga commit
  begin
      select sig_nro_cheque, serie, rowid
      into v_sig_nro_cheque, v_serie, v_fila
      from cc_par_chequeras
      where (cod_moneda = p_cod_moneda or cod_moneda is null)
        and (cod_modulo = p_cod_modulo or cod_modulo is null)
        and (cod_modalidad = p_cod_modalidad or cod_modalidad is null)
        and (cod_oficina = p_cod_oficina or cod_oficina is null)
        and (cod_tip_chequera = p_tip_chequera or cod_tip_chequera is null)
      For update;
  exception
     when no_data_found then
          raise_application_error(-20000,'No se encontro datos para el Tipo de Chequera '||p_tip_chequera||' '||sqlerrm);
     when too_many_rows then
          raise_application_error(-20000,'Varios registros para el Tipo de Chequera '||p_tip_chequera||' '||sqlerrm);          
  end;

  --Asigno Valores a los Parametros a Retornar
  if length(v_sig_nro_cheque + p_cantidad -1) > v_lon_sig_nro_che then
    p_cheque_inicial  := 1;
    p_cheque_final    := p_cantidad;
    p_serie           := v_serie + 1;
    
    if length(p_serie) > v_lon_ser_cheque then
       p_serie := 1;
    end if;    

    update cc_par_chequeras
       set sig_nro_cheque = P_CHEQUE_FINAL + 1,
           serie = p_serie   
     where rowid = v_fila;

  else
    p_cheque_inicial  := v_sig_nro_cheque;
    p_cheque_final    := (v_sig_nro_cheque + p_cantidad) - 1;
    p_serie           := v_serie;

    --Actualizo la tabla cc_par_chequeras con el valor del ultimo numero de cheque asignado
    update    cc_par_chequeras
    set       sig_nro_cheque = sig_nro_cheque + p_cantidad
    where rowid = v_fila;
  end if;
  
  exception
    when others then
      if sqlcode = -54 then --Nowait
    raise_application_error(-20000,'Registro utilizado por otro usuario'||sqlerrm);
    else
    raise_application_error(-20000,'Error PR_OBT_SIG_NRO_CHE '||sqlerrm);
    end if;
END;
/* Retorna el estado del cheque */
FUNCTION FU_OBT_EST_CHE
 (P_CUENTA IN CC_CHEQUERAS.NRO_CUENTA%TYPE
 ,P_CHEQUE IN CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE
 ,P_ERROR OUT VARCHAR2
 ,P_SERIE  IN CC_CHEQUERAS.SERIE%type default null --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
 )
 RETURN VARCHAR2
 IS

V_ESTADO VARCHAR2(1);
V_EST_CHEQ VARCHAR2(1);
V_POSCHEQUE NUMBER(8);
V_CHE_INICIAL NUMBER(8);
V_CAN_CHEQUES NUMBER(5);
V_EST_CHEQUES VARCHAR2(1000);
CURSOR cur_cheque IS
   SELECT estado,nro_che_inicial,can_cheques,est_cheques
     FROM  cc_chequeras
    WHERE nro_cuenta = p_cuenta
      AND p_cheque >= nro_che_inicial
      AND p_cheque <  nro_che_inicial + can_cheques
      AND p_cheque between nro_che_inicial and nro_che_final
      AND (serie = nvl(P_SERIE,serie) or serie is null) --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
 ORDER BY fec_solicitud desc;
begin
  open cur_cheque;
  fetch cur_cheque into v_est_cheq,v_che_inicial,v_can_cheques,v_est_cheques;
  close cur_cheque;
  if v_est_cheq is null then
    p_error := '2 Cheque '||to_char(p_cheque)||' Inexistente para la cuenta '||p_cuenta;
    return(null);
  end if;
  --Posicion del cheque evaluado
  v_poscheque := p_cheque-v_che_inicial+1 ;
  v_estado := substr(v_est_cheques,v_poscheque,1);
  return v_estado;
  exception
    when others then
      p_error := sqlerrm;
      return (null);
end;
/* Retorna el estado del cheque */
FUNCTION FU_OBT_EST_CHEQUE
 (P_CUENTA IN CC_CHEQUERAS.NRO_CUENTA%TYPE
 ,P_CHEQUE IN CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE
 )
 RETURN VARCHAR2
 IS

V_ESTADO VARCHAR2(1);
V_DES_ESTADO VARCHAR2(60);
V_EST_CHEQ VARCHAR2(1);
V_POSCHEQUE NUMBER(8);
V_CHE_INICIAL NUMBER(8);
V_CAN_CHEQUES NUMBER(5);
V_EST_CHEQUES VARCHAR2(1000);
CURSOR cur_cheque IS
   SELECT estado,nro_che_inicial,can_cheques,est_cheques
     FROM  cc_chequeras
    WHERE nro_cuenta = p_cuenta
      AND p_cheque >= nro_che_inicial
      AND p_cheque <  nro_che_inicial + can_cheques
      AND p_cheque between nro_che_inicial and nro_che_final
 ORDER BY fec_solicitud desc;
begin
  open cur_cheque;
  fetch cur_cheque into v_est_cheq,v_che_inicial,v_can_cheques,v_est_cheques;
  close cur_cheque;
  if v_est_cheq is null then
    --El cheque no existe
    return(null);
  end if;
  --Posicion del cheque evaluado
  v_poscheque := p_cheque-v_che_inicial+1 ;
  v_estado := substr(v_est_cheques,v_poscheque,1);
  --Traer la descripcion del estado
  begin
  select significado
     into v_des_estado
     from ba_cod_referencias
     where dominio = 'EST_CHEQUE'
       and val_minimo = v_estado;
  exception
    when others then
      return(null);
  end;
  return v_des_estado;
  exception
    when others then
      return (null);
end;
/* Elimina el cheque gerencia emitido y cambia a estado original.*/
FUNCTION FU_ELI_CHE_GER_EMI
 (P_CUENTA IN CC_CHE_GER_EMITIDOS.NRO_CUENTA%TYPE
 ,P_CHEQUE IN CC_CHE_GER_EMITIDOS.NRO_CHEQUE%TYPE
 )
 RETURN VARCHAR2
 IS


V_ESTADO_ANT VARCHAR2(1);
V_RESULT VARCHAR2(1000);
V_CUENTA_CERT VARCHAR2(15);
   v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
   v_ult_che_emitido cc_chequeras.ult_che_emitido%type;
begin

   --- Cambio de estado al cheque gerencia
   v_estado_ant := FU_ACT_CAM_EST_CHE(p_cuenta,p_cheque,'E',v_result,v_cuenta_cert);
   --- Actualizo ultimo cheque emitido
   if v_estado_ant = 'G' then
     --- Elimino el cheque gerencia
     delete cc_che_ger_emitidos
      where nro_cheque = p_cheque
        and nro_cuenta = p_cuenta; 
   end if;     
   -- Recupero la chequera
   BEGIN
      select nro_che_inicial, ult_che_emitido
        into v_nro_che_inicial, v_ult_che_emitido
        from cc_chequeras
       WHERE nro_cuenta = p_cuenta
         AND p_cheque >= nro_che_inicial
         AND p_cheque <  nro_che_inicial + can_cheques
         AND p_cheque between nro_che_inicial and nro_che_final;
   exception
      when no_data_found then
         raise_application_error(-20015,'Chequera no registrada');
   END;
   -- Verifico si el cheque corresponde al ultimo emitido actualizo chequera
   if p_cheque = v_ult_che_emitido then
      update cc_chequeras
         set ult_che_emitido = decode((nvl(ult_che_emitido,0)-1),(nro_che_inicial-1),null,ult_che_emitido-1)
       where nro_cuenta = p_cuenta
         and nro_che_inicial = v_nro_che_inicial;
   end if;
   return v_result;
   exception
      when others then
       v_result := 'Elim.cheq.ger.'||sqlerrm;
     raise_application_error(-20014,v_result);
end;
/* Retorna la direccion de la chequera */
FUNCTION FU_OBT_DIR_CHEQUERA
 (P_NRO_CUENTA IN CC_CHEQUERAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_DIRECCION  VARCHAR2(500);
V_COD_PERSONA VARCHAR2(10);
cursor vdir is
   select direccion||decode(numero,null,'',' '||numero)
     from ba_direcciones ba,
          ge_dir_envios gd,
          ge_cta_clientes gc
    where gc.nro_cuenta  = p_nro_cuenta
      and gc.relacion = 'P'
      and gc.cod_persona = gd.cod_persona
      and gd.tip_envio = 'D'
      and (gd.nro_cuenta = p_nro_cuenta or gd.nro_cuenta is null)
      and gd.cod_persona = ba.cod_persona
      and gd.referencia = ba.cod_direccion
      and gd.referencia is not null
    order by nvl(gd.nro_cuenta,'ZZZ');
begin
 --Ver si tiene direccion de envio del tipo direccion o traer la direccion princ.
 open vdir;
 fetch vdir into v_direccion;
 close vdir;
 if v_direccion is null then
      select cod_persona
        into v_cod_persona
        from ge_cta_clientes gc
       where gc.nro_cuenta  = p_nro_cuenta
         and gc.relacion = 'P';
       v_direccion := FUE_OBT_DIR_PRINCIPA(v_cod_persona);
 end if;
 return trim(replace(replace(v_direccion,chr(10),''),chr(13),''));
exception
   when others then
      return null;
end;
/* Retorna el nombre de la chequera */
FUNCTION FU_OBT_NOM_CHEQUERA
 (P_NRO_CUENTA IN CC_CHEQUERAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_NOM_CHEQUERA  CC_CTA_CORRIENTES.NOM_CHEQUERA%TYPE;
v_cod_modalidad number(6);
begin
 if p_nro_cuenta is null then
    v_nom_chequera := 'CHEQUE VENTANILLA';
 else
   select cod_modalidad
     into v_cod_modalidad
     from ge_cuentas
    where nro_cuenta = p_nro_cuenta;
   if v_cod_modalidad = 41 then
      select nom_chequera
        into v_nom_chequera
        from cc_cta_corrientes
       where nro_cuenta = p_nro_cuenta;
   else
      select denominacion
        into V_NOM_CHEQUERA
        from cc_cta_bancarias
       where nro_cuenta = p_nro_cuenta;
   end if;
 end if;
 return v_nom_chequera;
exception
   when others then
      return null;
end;
procedure PR_OBT_RES_CHEQUERA
 (p_nro_cuenta in varchar2,
  p_can_sol in out number,
  p_can_ent in out number,
  p_can_pag in out number,
  p_can_onp in out number,
  p_can_anu in out number,
  p_can_cer in out number,
  p_can_tot in out number,
  p_por_uti in out number
  ) is

  v_chepag    number := 0;
  v_cheonp    number := 0;
  v_cheanu    number := 0;
  v_checer    number := 0;
  v_cheent    number := 0;
  v_chesol    number := 0;
  v_chetot    number := 0; --total entregadas

  cursor chequeras is
    select est_cheques
      from cc_chequeras
      where nro_cuenta = p_nro_cuenta;

begin

  p_can_sol := 0;
  p_can_ent := 0;
  p_can_pag := 0;
  p_can_onp := 0;
  p_can_anu := 0;
  p_can_cer := 0;
  p_por_uti := 0;
  p_can_tot := 0;

  --Cantidad de hojas solicitadas
  begin
      select nvl(sum(cantidad*can_hojas),0)
        into v_chesol
        from cc_sol_chequeras
       where nro_cuenta = p_nro_cuenta
         and estado = 'S';
  exception
    when no_data_found then null;
  end;

  for reg in chequeras loop
    v_chesol  := v_chesol + nvl(pac_che.fu_obt_can_est_che('S',nvl(reg.est_cheques,'z')),0);
    v_cheent  := v_cheent + nvl(pac_che.fu_obt_can_est_che('E',nvl(reg.est_cheques,'z')),0);
    v_chepag  := v_chepag + nvl(pac_che.fu_obt_can_est_che('P',nvl(reg.est_cheques,'z')),0);
    v_cheonp  := v_cheonp + nvl(pac_che.fu_obt_can_est_che('O',nvl(reg.est_cheques,'z')),0);
    v_cheanu  := v_cheanu + nvl(pac_che.fu_obt_can_est_che('A',nvl(reg.est_cheques,'z')),0);
    v_checer  := v_checer + nvl(pac_che.fu_obt_can_est_che('C',nvl(reg.est_cheques,'z')),0);
  end loop;

  --Total de Cheques en poder del cliente
  v_chetot := nvl(v_cheent,0)+nvl(v_chepag,0)+nvl(v_cheonp,0)+nvl(v_cheanu,0)+nvl(v_checer,0);

  p_can_sol := v_chesol;
  p_can_ent := v_cheent;
  p_can_pag := v_chepag;
  p_can_onp := v_cheonp;
  p_can_anu := v_cheanu;
  p_can_cer := v_checer;
  p_can_tot := nvl(v_chetot,0)+nvl(v_chesol,0);

  If nvl(v_chetot,0) <> 0 then
    p_por_uti := round(((nvl(v_chepag,0)+nvl(v_cheonp,0)+nvl(v_cheanu,0)+nvl(v_checer,0))* 100)/nvl(v_chetot,0),2);
  End if;
end;
END PAC_CHE;
/
