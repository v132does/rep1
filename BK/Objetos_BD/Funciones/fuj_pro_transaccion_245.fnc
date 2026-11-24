CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_245
 (p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja in varchar2,        -- Nro de Caja
  p_cod_tip_operacion in number,   -- codigo del tipo de operacion
  p_nro_documento     in varchar2 default null,  -- nro de documento
  p_nombre            in varchar2 default null,  --nombre de la persona
  p_apellido          in varchar2 default null,  --apellido de la persona
  p_tip_documento     in varchar2 default null,  --tip_documento
  p_pai_documento     in varchar2 default null,  --pais documento
  p_cod_moneda        in varchar2 default null,  -- moneda
  p_importe           in number   default null,  -- importe de la operacion
  p_cotizacion        in number   default null,  -- cotizacion
  p_efectivo          in number   default null,  --mto efectivo
  p_tip_retencion     in number default null,    --retencion
  p_cheque            in number default null,    --mto cheque
  --agregado cheq nstro bco
  p_nro_che_ntro      in varchar2 default null,  --nro cheq ntro bco
  p_che_ntro_bco      in number default null,    --mto cheq ntro bco
  --agregado para credito en cuenta
  p_cta_credito       in varchar2 default null,  --cta credito
  p_mto_cuenta        in number default null,    --mto cta credito
  p_cta_cliente       in varchar2 default null,
  -- Agregado para detalle de cheques, si es uno solo
  p_cod_banco         in varchar2 DEFAULT NULL,  -- codigo del banco
  p_nro_cheque        in varchar2 DEFAULT NULL)  -- numero de cheque

 RETURN long
 IS
  -- defino por defecto el modulo y modalidad a utilizar 
  v_cod_modulo        number(3) := 9;    -- Caja
  v_cod_modalidad     number(3) := 91;   -- Caja
  v_cod_transaccion   number(4) := 245;  -- transaccion
  v_cod_usuario       varchar2(10) := upper(user); --usuario
  -- Datos de la caja

  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida        long;        -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000'; -- sin errores
  v_msj_respuesta     long := ''; -- sin errores
  -- variables para guardar los datos de la operacion principal

  v_nro_operacion     number(15);
  v_tip_mov_rubro     varchar2(1);
  --Datos de la operacion
  v_afe_posicion       lc_tip_operaciones.afe_posicion%type;
  v_afe_limite         lc_tip_operaciones.afe_limite%type;
  v_afe_che_viajero    lc_tip_operaciones.afe_che_viajero%type;
  v_afe_transferencia  lc_tip_operaciones.afe_transferencia%type;
  v_caja               lc_tip_operaciones.caja%type;
  v_tip_valor          lc_tip_operaciones.tip_valor%type;
  v_cod_mod_origen     lc_tip_operaciones.cod_mod_origen%type;
  v_cod_mod_operacion  lc_tip_operaciones.cod_modulo%type;
  v_cod_mad_operacion  lc_tip_operaciones.cod_modalidad%type;
  v_cod_tra_operacion  lc_tip_operaciones.cod_transaccion%type;
  v_cod_mad_hijo       lc_tip_operaciones.cod_mad_hijo%type;
  v_afe_cod_transaccion lc_tip_operaciones.afe_cod_transaccion%type;
  v_cod_tra_cargo1     lc_tip_operaciones.cod_tra_cargo1%type;
  v_cod_tra_cargo2     lc_tip_operaciones.cod_tra_cargo2%type;
  v_cod_tra_cargo3     lc_tip_operaciones.cod_tra_cargo3%type;
  v_cotizacion         ge_cotizaciones.val_conversion%type;
  v_nombre             ba_personas.nom_completo%type;
  v_nom_completo       ba_personas.nom_completo%type;
  v_cod_moneda_lim     ba_monedas.cod_moneda%type;
  v_mto_lim            number(18,2);
  v_equivalente        number;
  v_mto_cargo1         number;
  v_mto_cargo2         number;
  v_mto_cargo3         number;
  v_total              number;
  v_cod_tasa           number;
  v_val_tasa           number;
  v_cod_tasa1          number;
  v_val_tasa1          number;
  v_cod_tasa2          number;
  v_val_tasa2          number;
  v_cod_tasa3          number;
  v_val_tasa3          number;
  v_mov_mto_cargo      ge_movimientos.monto%type;
  v_mov_cod_tra_cargo  ge_movimientos.cod_transaccion%type;
  v_mov_cod_tasa       number;
  v_mov_val_tasa       number;
  v_tra_impuesto       ge_movimientos.cod_transaccion%type;
  v_impuesto           ge_movimientos.monto%type;
  v_des_cargo          ge_transacciones.descripcion%type;
  v_hora               ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia      ge_movimientos.nro_secuencia%type:=0;
  r_gmovi              ge_movimientos%rowtype;
  v_mon_local          ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_mon_fuerte         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
  v_cta_cambios        lc_cta_cambios.nro_cuenta%type;
  v_lim_utilizado      lc_cta_cambios.mto_limite%type;
  v_cod_retencion      ge_movimientos.cod_retencion%type;
  v_fec_fin_retencion  date;
  v_cod_persona        ba_personas.cod_persona%type;
  v_tip_aplicacion     lc_tip_ope_oficinas.tip_aplicacion%type;
  v_cod_rubro          lc_tip_ope_oficinas.cod_rubro%type;
  v_cod_tip_referencia lc_tip_ope_oficinas.cod_tip_referencia%type;
  v_nro_referencia     lc_tip_referencias.sig_numero%type;
  v_est_cta            lc_cta_cambios.estado%type;
  v_cod_ofi_cta        lc_cta_cambios.cod_oficina%type;
  v_rango              ge_movimientos.monto%type;
  v_est_mvto           ge_movimientos.estado%type :='N';--mvto. principal
  v_est_mvto_resto     ge_movimientos.estado%type :='N';--otros movimientos
  v_msj                varchar2(500);
  v_msj_limite         varchar2(500);
  v_msj_monto          varchar2(500);
  v_msj_lim_var        VARCHAR2(2000);
  v_aut_monto          varchar2(1)  := 'N';
  v_tip_monto          varchar2(1)  := 'Z';
  v_mto_cheque         number;
  v_des_operacion      lc_tip_operaciones.descripcion%type;
  v_aut_limite         varchar2(1):='N';
  v_aut_cotizacion     varchar2(1):='N';
  v_aut_lim_var        varchar2(1):='N';

  v_tip_documento       ba_personas.cod_tip_documento%type;
  v_cod_pais           ba_personas.cod_pais%type;
  v_apellido           ba_personas.nom_completo%type;
  v_tipo               ba_personas.tipo%type;
  v_fec_nacimiento     date;
  v_error              varchar2(2000);
  --emitir comprobante automatico
  v_emi_aviso       ge_movimientos.emi_aviso%type := 'S';
  v_cod_tra_cheque  ge_movimientos.cod_transaccion%type;
  v_ubi_banco       ge_bancos.ubicacion%type;
  v_des_banco       ge_bancos.descripcion%type;
  v_cta_cheque      cc_chequeras.nro_cuenta%type;

  v_tip_retencion   ge_movimientos.cod_retencion%type;
  v_cod_ope_bcp     lc_tip_operaciones.cod_tip_ope_bcp%type;

  v_cod_mod_cuenta  ge_cuentas.cod_modulo%type;
  v_cod_mad_cuenta  ge_cuentas.cod_modalidad%type;
  v_est_cuenta      ge_cuentas.estado%type;
  v_sal_disp_cuenta ge_cuentas.sal_contable%type;
  v_procesa         varchar2(1);
  v_ofi_cta_cliente ge_cuentas.cod_oficina%type;
  v_est_ant_cta_cliente  ge_cuentas.estado%type;
  v_monto ge_aut_pedidos.mto_mon_fuerte%type;
  v_redondeo_ml     number(5);
  v_cli_frecuente   varchar2(1) := 'N';
       /*CROCLIJUD-5*/
  v_cod_cau_judicial   ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
   -- CRO-JM-03/2015: CROGEFIT-3
  v_mto_calculado    number;
  v_nro_cuenta       cj_acu_imp_transacciones.nro_cuenta%type;
  v_cliente varchar2(1) := 'N'; 
  v_exi_bse_bcp varchar2(1) := 'N';
  v_cod_per_2        ba_personas.cod_persona%type;
  v_abr_tip_doc ba_tip_documentos.abreviatura%type;
  v_abr_cod_pai_iso ba_paises.cod_pai_iso%type;
  v_mto_max_ope ge_movimientos.monto%type := fug_obt_pardinamico('MTO_MAX_OPE_CAM_NO_CLIENTE');
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion
    (p_tip_movimiento in varchar2,
     p_tip_monto      in varchar2,
     p_cod_moneda     in varchar2,
     p_importe        in number,
     p_nro_secuencia  in number)   is
  v_mto_cheque        number(18,2) := 0;
  v_mto_che_ntro_bco  number(18,2) := 0;
  v_mto_efectivo      number(18,2) := 0;
  v_cta_cam_global     lc_cta_cambios.nro_cuenta%type;
  begin
    -- evaluo el tipo de valor
    if p_tip_monto = 'E' then
      v_mto_efectivo := p_importe;
    elsif p_tip_monto ='C' then
      v_mto_che_ntro_bco := p_importe;
    else
      v_mto_cheque   := p_importe;
    end if;
    if p_tip_movimiento = 'D' then  -- compra
      -- sumar a los saldos  -- Actualizo el control de caja
      update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_cheque,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_che_ntro_bco,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
     else
      -- se resta del saldo del cajero -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_mto_efectivo,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_efectivo,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
     end if;
     --WA:10/09/2013 insertamos el Nro de Cuenta de Cambios, si es Cheque Otros Bancos
     --y no es cta bolsa
     v_cta_cam_global:= FUG_OBT_PARDINAMICO('CTA_CAM_CLI_TEMPORAL');
      if p_tip_monto in ('T','S','O') and v_cta_cambios is not null
        and v_cta_cambios <> v_cta_cam_global then
        insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja,
                nro_documento,  monto, tip_monto, tipo,nro_cuenta)
            values
               (v_fec_actual, v_hora, v_cod_usuario, p_nro_secuencia,
                v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
                v_nro_operacion, p_importe,
                p_tip_monto, p_tip_movimiento, v_cta_cambios); /* es D-ebito o C-redito */
                /*E-fectivo/C-heq Ntro.Bco /O-Cheq.Otr.Bco(1) /T-Otr.Bco Tarde(2) /S-Otr.Bco(3) PLoc /X-Otr.Bco(3) PExt*/
      else
          -- genero el movimiento por la operacion compra/venta
         insert into cj_movimientos
             (fecha, hora, cod_usuario, nro_secuencia,
              cod_tra_padre, cod_mod_padre, cod_mad_padre,
              cod_oficina, cod_moneda, nro_caja,
              nro_documento,  monto, tip_monto, tipo)
          values
             (v_fec_actual, v_hora, v_cod_usuario, p_nro_secuencia,
              v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
              v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
              v_nro_operacion, p_importe,
              p_tip_monto, p_tip_movimiento); /* es D-ebito o C-redito */
              /*E-fectivo/C-heq Ntro.Bco /O-Cheq.Otr.Bco(1) /T-Otr.Bco Tarde(2) /S-Otr.Bco(3) PLoc /X-Otr.Bco(3) PExt*/
       end if;
  end lp_gen_transaccion;
/*recupera cta limite del cliente */
FUNCTION lf_obt_cta_cliente RETURN varchar2 IS
v_nro_cuenta lc_cta_cambios.nro_cuenta%type;
BEGIN
  SELECT B.NRO_CUENTA
    INTO v_nro_cuenta
    FROM LC_CTA_CAMBIOS B, GE_CTA_CLIENTES  A
   WHERE ESTADO in('N','A')
     AND A.NRO_CUENTA = B.NRO_CUENTA
     AND RELACION = 'P'
     AND A.COD_MODULO = 7
     AND A.COD_MODALIDAD = 70
     AND A.COD_PERSONA = v_cod_persona
     AND ROWNUM = 1;--en teoria debe haber un solo limite x cliente,siempre en USD
   return v_nro_cuenta;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    --recuperar par dinamico para cuenta bolsa x la oficina
    v_nro_cuenta:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
    return v_nro_cuenta;
  WHEN OTHERS THEN
    v_cod_respuesta := '026'; -- error
    v_msj_respuesta := 'Recup.Cta. Cliente '||v_cod_persona;
END;

    -- Agregado en fecha 02/08/2013 por usuario XPY9515
    -- Llama al procedimiento almacenado que controla si el monto
    -- de la operacion de compra alcanza o supera el limite
    -- de valor de riesgo permitido. -- CNFLIMVAR-65 --
    PROCEDURE lp_controlar_limites_var IS
        v_cod_error NUMBER(2,0);
        v_estado    ge_movimientos.estado%type;
    BEGIN
    v_msj_respuesta := 'CONTROLAR LIMITES VAR';

        pal_var.pr_wrap_con_pos_cambio (
            USER, -- usuario que realiza la operacion
            v_cod_oficina , -- codigo de oficina
            p_cod_moneda, -- moneda
            p_importe, -- importe
            p_cotizacion, -- cotizacion
            p_cod_tip_operacion, -- tipo operacion
            v_cod_mad_operacion, -- modalidad
            'CON',
            v_fec_actual,
            v_hora,
            'N', -- indica si es operacion de homebanking
            'C', -- generar autorizacion
            v_estado,  -- estado del movimiento para Autorizacion por Limites VaR
            v_cod_error,
            v_msj_lim_var -- mensaje de retorno
        );
        if v_cod_error is not null then
          
        IF v_cod_error = 0 THEN
            IF nvl(v_estado,'-') = 'X' THEN  -- pendiente de autorizacion
                v_est_mvto := 'X';
                v_cod_respuesta := '000';
                v_aut_lim_var := 'S';
                v_est_mvto_resto := 'P';
                v_msj_respuesta := v_msj_lim_var;
            END IF;
        ELSE
            v_cod_respuesta := '999';
            v_msj_respuesta := v_msj_lim_var;
        END IF;
        end if;
    EXCEPTION
        WHEN OTHERS THEN
             v_cod_respuesta := '998';
             v_msj_respuesta := v_msj_respuesta||': '||SQLERRM;
    END;


/*inicia proceso principal*/
begin    
   if p_cod_tip_operacion is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese el Tipo de operacion a realizar.';       
   elsif p_nro_documento is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese el Nro. de documento.';
   elsif p_nombre is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese el Nombre de la persona.';
   elsif p_cotizacion is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese la Cotizacion.';
   elsif p_importe is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese el Importe de la operacion.';
   elsif p_cod_moneda is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese la Moneda.';  
   elsif p_efectivo is null and p_cheque is null and p_che_ntro_bco is null and p_mto_cuenta is null then
      v_cod_respuesta := '001';
      v_msj_respuesta := 'ERROR: Ingrese Monto';
   end if;
   if nvl(p_efectivo,0)<=0 and nvl(p_cheque,0)<=0 and nvl(p_che_ntro_bco,0)<=0 and nvl(p_mto_cuenta,0)<=0 then
      v_cod_respuesta := '001';
      v_msj_respuesta := 'ERROR: Ingrese Monto';
   end if;
   if v_cod_respuesta = '000' then
      --validar los datos ingresados
      v_msj_salida:= FUJ_VAL_TRANSACCION_245(p_nro_operacion, p_nro_caja, /*p_nro_comprobante,*/
            p_cod_tip_operacion, p_nro_documento, p_nombre,p_apellido,p_tip_documento,p_pai_documento, p_cod_moneda, p_importe, p_cotizacion, p_efectivo,
            p_tip_retencion, p_cheque, p_nro_che_ntro, p_che_ntro_bco, p_cta_credito, p_mto_cuenta,
            p_cta_cliente, p_cod_banco, p_nro_cheque);
      if v_msj_salida NOT LIKE '%~OK~%' THEN
         return v_msj_salida;

      END IF;
   end if;
   --recupera persona
   if v_cod_respuesta = '000' then
      begin
         select cod_persona, substr(nom_completo,1,100), cod_persona
           into v_cod_persona, v_nom_completo,v_cod_per_2
           from ba_personas
          where nro_documento = p_nro_documento;
      exception
         when too_many_rows then
             v_cod_respuesta := '002';
             v_msj_respuesta := 'Varias Personas con igual nro.documento '||p_nro_documento;
         when no_data_found then
             if v_cod_persona is null  then --Si no esta en la tabla ba_personas busco en la base del BCP 
                PRL_OBT_DAT_PER_BCP(p_nro_documento, v_tip_documento, v_cod_pais,
                                   v_nombre,v_apellido, v_error,v_abr_tip_doc,v_abr_cod_pai_iso);                 
               --Insertar en ba_personas
               if v_error = 'Inexistente' then
                  v_exi_bse_bcp := 'N';
                  Begin 
                    Select t.cod_tip_documento
                      into v_tip_documento
                      from ba_tip_documentos t 
                    where t.abreviatura = p_tip_documento;
                  Exception 
                      When others then 
                        v_tip_documento := 1;
                  End;
                  
                 Begin 
                    Select t.cod_pais 
                      into v_cod_pais
                      from ba_paises  t 
                    where t.cod_pai_iso = p_pai_documento;
                  Exception 
                      When others then 
                         v_cod_pais :=  1;
                  End;
                 
                  v_nombre := p_nombre;
                  v_apellido :=  p_apellido;
               end if;
               
            else --Si existe en la tabla ba_personas verifico que sea Cliente 
              v_exi_bse_bcp := 'S';
               v_cliente := fug_es_cliente(v_cod_persona);
            end if;         
          /*  --primero buscar en la base del BCP, e insertar en ba_personas si encuentra, sino pedir
            prl_obt_per_bdbcp(p_nro_documento, v_tip_documento, v_cod_pais, v_nombre,
                              v_apellido, v_tipo, v_fec_nacimiento, v_error);
             if v_error is not null then
                v_cod_respuesta := '003';
               v_msj_respuesta := v_error;
            else -- si no retorna msj de error ni nombre -> no existe la persona
               if v_nombre is null then -- no existe en bcp
                  if pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,pag_gen.fu_obt_mon_fuerte,p_IMPORTE) >
                       fug_obt_pardinamico('MTO_MIN_CAM_DOCUMENTO',7,v_cod_mad_operacion,null,null) then
                      v_cod_respuesta := '017';
                     v_msj_respuesta := 'No existe Persona con el nro.documento '||p_nro_documento||'. Ingrese una persona existente.';
                  else
                     if p_nombre is null then
                         v_cod_respuesta := '018';
                        v_msj_respuesta := 'ERROR: Ingrese el Nombre de la Persona';
                     end if;
                   end if;
               else--encontro en bcp
                  v_nom_completo:= substr(v_nombre||' '||v_apellido,1,120);
               end if;
             end if;*/
      end;
   end if;
  if v_cod_respuesta = '000' then
       ---Verifica si el Cliente o un Vinculado a la Cuenta esta inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
     v_cod_persona := fue_obt_cod_persona(p_nro_documento);
     if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona) Then
           v_cod_respuesta := '006';
           v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Juridico';
     End If;
   end if;

   if v_cod_respuesta = '000' then
      -- Obtengo los datos de la caja x moneda local------------------
      prj_obt_datos_caja(p_nro_caja,
                       pag_gen.fu_obt_mon_local,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques);
      if v_estado = -1 then
         v_cod_respuesta := '006'; -- error, no existe registro de caja
         v_msj_respuesta := 'Caja inexistente!!';
      elsif v_estado in (0,2) then
         v_cod_respuesta := '004'; -- error
         v_msj_respuesta := 'Caja no esta habilitada para esta Operacion en '||pag_gen.fu_obt_mon_local;
      elsif v_fec_caja <> v_fec_actual then
         v_cod_respuesta := '005'; -- error
         v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      end if;
   end if;
   if v_cod_respuesta = '000' then
      --recuperar los datos de la operacion
      begin
         select a.afe_posicion, a.afe_limite, a.afe_che_viajero, a.afe_transferencia,
                a.caja, a.tip_valor, a.cod_mod_origen, a.cod_modulo, a.cod_modalidad,
                a.cod_transaccion, a.cod_mad_hijo, a.afe_cod_transaccion,
                a.cod_tra_cargo1, a.cod_tra_cargo2, a.cod_tra_cargo3,
                b.tip_aplicacion, b.cod_rubro, b.cod_tip_referencia, a.descripcion, a.cod_tip_ope_bcp
           into v_afe_posicion, v_afe_limite, v_afe_che_viajero, v_afe_transferencia,
                v_caja, v_tip_valor, v_cod_mod_origen, v_cod_mod_operacion, v_cod_mad_operacion,
                v_cod_tra_operacion, v_cod_mad_hijo, v_afe_cod_transaccion,
                v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3,
                v_tip_aplicacion, v_cod_rubro, v_cod_tip_referencia, v_des_operacion, v_cod_ope_bcp
           from lc_tip_ope_oficinas b, lc_tip_operaciones a
          where b.cod_tip_operacion = a.cod_tip_operacion
            and b.cod_moneda = p_cod_moneda
            and b.cod_oficina = v_cod_oficina
            and a.cod_tip_operacion = p_cod_tip_operacion
            and a.cod_tip_operacion in (11,26,18,30)--compra y vta efectivo,compra de cheques
            and a.nivel = 1
            and a.cod_modalidad in (71,72);
      exception
         when no_data_found then
            v_cod_respuesta := '007';
            v_msj_respuesta := 'Tipo de Operacion no valido.';
      end;
   end if;
   v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_mad_operacion,v_mon_local);
   --solo si es compra de cheque q tenga cheque
   if v_cod_respuesta = '000' then
      if v_cod_mad_operacion = 71 then
         if p_cod_tip_operacion not in (18) then
            if nvl(p_cod_banco,0) >0 or nvl(p_nro_cheque,0)>0 or nvl(p_che_ntro_bco,0)>0 or nvl(p_nro_che_ntro,0)>0 then
               v_cod_respuesta := '007';
               v_msj_respuesta := 'Tipo de Operacion no permite cheque.';
            end if;
         else -- si es compra tiene q cargar si o si el cheque
            --ya no es obligatorio porq se pueden comprar varios cheques
            null;
            
         end if;
      end if;
   end if;
   
   ---Verifica Monto Superior USD (Solo Clientes - Venta Efectivo)
   if v_cod_per_2 is not null and p_cod_tip_operacion = 26 then
      --Valida el monto y tipo de Persona
      if fuj_val_mto_max_efe_cam(v_cod_per_2,
                                 pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,pag_gen.fu_obt_mon_fuerte, p_importe, pal_cam.FU_OBT_COT_VENTA(p_cod_moneda) )
                                 ) = 'N' then
         v_cod_respuesta := '003'; -- error
         v_msj_respuesta := '! Operacion Supera Monto Efectivo, debe ser ingresada como Depósito en Cta.';
      end if;  
   end if;

   --recupera los cargos
   if v_cod_respuesta = '000' then
     --obtiene cta de cambios del cliente
      v_cta_cambios := lf_obt_cta_cliente;

      v_equivalente :=round(P_IMPORTE * P_COTIZACION,v_redondeo_ml);
      --cargo 1
      if v_cod_tra_cargo1 is not null then
         begin
           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
           if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
            or v_cod_persona is null then
              pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, p_cod_moneda,
                 p_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null, v_des_cargo,
                 v_mto_cargo1, v_cod_tasa1, v_val_tasa1);
           elsif v_cod_persona is not null then
              pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, p_cod_moneda,
                 p_importe, v_equivalente, v_cod_oficina, null, v_cod_persona, v_des_cargo,
                 v_mto_cargo1, v_cod_tasa1, v_val_tasa1);
           end if;
         exception
            when others then
               v_cod_respuesta := '010';
               v_msj_respuesta := 'Error Cargos1 '||substr(sqlerrm,1,400);
         end;
      end if;
      if v_cod_respuesta = '000' then
         --cargo 2
         if v_cod_tra_cargo2 is not null then
            begin
             --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
             if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
              or v_cod_persona is null then
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_cod_mad_operacion, p_cod_moneda,
                    p_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null, v_des_cargo,
                    v_mto_cargo2, v_cod_tasa2, v_val_tasa2);
             elsif v_cod_persona is not null then
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_cod_mad_operacion, p_cod_moneda,
                    p_importe, v_equivalente, v_cod_oficina, null, v_cod_persona, v_des_cargo,
                    v_mto_cargo2, v_cod_tasa2, v_val_tasa2);
             end if;
            exception
               when others then
                  v_cod_respuesta := '011';
                  v_msj_respuesta := 'Error Cargos2 '||substr(sqlerrm,1,400);
            end;
         end if;
      end if;
      if v_cod_respuesta = '000' then
         --cargo 3
         if v_cod_tra_cargo3 is not null then
            begin
             --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
             if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
              or v_cod_persona is null then
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo3, v_cod_mad_operacion, p_cod_moneda,
                    p_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null, v_des_cargo,
                    v_mto_cargo3, v_cod_tasa3, v_val_tasa3);
             elsif v_cod_persona is not null then
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo3, v_cod_mad_operacion, p_cod_moneda,
                    p_importe, v_equivalente, v_cod_oficina, null, v_cod_persona, v_des_cargo,
                    v_mto_cargo3, v_cod_tasa3, v_val_tasa3);
             end if;
            exception
               when others then
                  v_cod_respuesta := '012';
                  v_msj_respuesta := 'Error Cargos3 '||substr(sqlerrm,1,400);
            end;
         end if;
      end if;
      --si es compra se restan los cargos, si es venta se suman
      if v_cod_respuesta = '000' then
         if v_cod_mad_operacion = 71 then
            v_total := nvl(v_equivalente,0) - (nvl(round(v_mto_cargo1,v_redondeo_ml),0) + nvl(round(v_mto_cargo2,v_redondeo_ml),0) + nvl(round(v_mto_cargo3,v_redondeo_ml),0));
         elsif v_cod_mad_operacion = 72 then
            v_total := v_equivalente + (nvl(round(v_mto_cargo1,v_redondeo_ml),0) + nvl(round(v_mto_cargo2,v_redondeo_ml),0) + nvl(round(v_mto_cargo3,v_redondeo_ml),0));
         end if;
      end if;

   end if;
   --valida los montos ingresados
   if v_cod_respuesta = '000' then
      if v_cod_mad_operacion = 71 then --compra puede haber efectivo y credito en cuenta como pago
         if nvl(p_efectivo,0) + nvl(p_mto_cuenta,0) <> v_total then
            v_cod_respuesta := '012';
            v_msj_respuesta := 'Error: montos mal detallados';
         end if;
      else--si es venta puede haber efectivo y cheque
         if nvl(p_efectivo,0) + nvl(p_cheque,0) + nvl(p_che_ntro_bco,0) <> v_total then
            v_cod_respuesta := '012';
            v_msj_respuesta := 'Error: montos mal detallados';
         end if;
      end if;
   end if;

   if v_cod_respuesta = '000' then
      -- Inicializacion de la aplicacion y el modulo
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
      --- Inicializo el numero de operacion gral para todas las operaciones
      -- solo si no ingreso comprobante manual
     
         begin
            v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_mad_operacion, p_cod_moneda, v_cod_oficina)+1;
            prg_act_par_dinamico('NRO_RECIBO',7, v_cod_mad_operacion, p_cod_moneda, v_cod_oficina, v_nro_operacion);
         exception
            when others then
                 if sqlcode <= -20000 then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'Asigna nro.operacion '||sqlerrm;
                 end if;
         end;
     
      if v_cod_respuesta = '000' then
        --asigno nro_referencia, se utiliza secuencia para evitar bloqueos
        v_nro_referencia:=fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_referencia,3,0)||'');
      END IF;
   end if;
   ---Verifica si el Cliente o un Vinculado a la Cuenta esta inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
   if v_cod_respuesta = '000' then
     v_cod_persona := fug_obt_cli_principal(p_cta_cliente);
     if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_cta_cliente) Then
       v_cod_respuesta := '029';
       v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Juridico';
     end if;
   end if;

   --verificar si se puede realizar la operacion por la cuenta cliente de arriba, por venta de deposito
   if v_cod_respuesta = '000' then
      IF v_tip_aplicacion = 'C' and v_cod_mad_operacion = 72 and p_cta_cliente is not null then
         pag_cta.PR_OBT_CUENTA(p_cta_cliente);
         v_ofi_cta_cliente := pag_cta.g_ctas.cod_oficina;
         v_est_ant_cta_cliente := pag_cta.G_CTAS.estado;
         if pag_cta.fu_obt_cod_error() <> 0 then
           v_cod_respuesta := '014';
           v_msj_respuesta := 'Recup.Cta.Cliente '||p_cta_cliente||'-'||pag_cta.fu_obt_msj_error();
         end if;
         if v_cod_respuesta = '000' then
           --Verifica la Operacion
           pag_cta.pr_ver_operacion(p_cta_cliente,
                                 602,--credito en cuenta
                                 7,        -- cod_mod_padre
                                 v_cod_mad_operacion,     -- cod_mod_hijo
                                 'C',                          -- Tipo Credito
                                 p_cod_moneda,   -- Moneda de la Cta. de Debito(Moneda de la Oper.)
                                 p_importe,
                                 v_cod_oficina,        -- cod_ofi_origen
                                 v_cod_mod_cuenta,
                                 v_cod_mad_cuenta,
                                 v_est_cuenta,    -- toma el estado de la cuenta
                                 v_sal_disp_cuenta,-- sal_disponible
                                 v_procesa);      -- procesa (s/n              -- procesa (s/n)
           if v_procesa = 'N' then
              v_cod_respuesta := '016';
              v_msj_respuesta := pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error();
           end if;
        end if;
      else
        if v_tip_aplicacion = 'C' and v_cod_mad_operacion = 72 and p_cta_cliente is null then
            v_cod_respuesta := '020'; -- error
            v_msj_respuesta := 'ERROR: Ingrese la cuenta para Depósito en Cuenta.';             
        end if;
      end if;--afecta cta
   end if;

  --inserta la persona si no existe
   if v_cod_respuesta = '000' then
     if v_cod_persona is  null then --persona inexistente
        if v_nombre is not null then 
           begin            
             PRL_INS_PER_NO_CLIENTE(p_nro_documento,v_tip_documento,
                                    v_cod_pais,v_nombre,v_apellido,'F',v_cod_persona);    
             v_cod_per_2 := v_cod_persona;                                    
          exception
             when others then
                   v_cod_respuesta := '022';
                   v_msj_respuesta := 'InsPers '||sqlerrm;
           end;
       end if;
     end if;
  end if;

   --verifica si debe pedir autorizacion x cotizacion
   -- valida cotizacion --valida rango permitido
   if v_cod_respuesta = '000' then
      if v_cod_mad_operacion = 71 then --compra
         v_cotizacion := pal_cam.FU_OBT_COT_COMPRA(p_cod_moneda);
      elsif v_cod_mad_operacion = 72 then --venta
         v_cotizacion := pal_cam.FU_OBT_COT_VENTA(p_cod_moneda);
      else
         v_cod_respuesta := '013';
         v_msj_respuesta := 'Modalidad '||v_cod_mad_operacion||' no permitida.';
      end if;
   end if;
   if v_cod_respuesta = '000' then
      v_rango :=FUG_OBT_PUN_COTIZACION(v_cod_usuario,p_cod_moneda,v_cod_oficina,v_cod_mad_operacion);
      if p_cotizacion > (nvl(v_cotizacion,0) + nvl(v_rango,0)) or
         p_cotizacion < (nvl(v_cotizacion,0) - nvl(v_rango,0)) then
       v_aut_cotizacion := 'S';
          v_est_mvto:='X';
          v_est_mvto_resto :='P';
          v_msj :='Necesita autorizacion por cotizacion '||to_char(p_cotizacion)||' fuera de rango. Sobre la cotiz. base de '
                  ||v_cotizacion||'. '||v_des_operacion||' Nro. '||v_nro_operacion||'. ';
      else
          v_est_mvto:='N';
          v_est_mvto_resto :='N';
      end if;
   end if;
   --verifica si debe pedir autorizacion por sobrepasar limite
   if v_cod_respuesta = '000' then
     --recuperar datos de la cta de cambios
      pag_cta.pr_obt_cuenta(v_cta_cambios);
      v_est_cta := pag_cta.g_ctas.estado;
      v_cod_ofi_cta := pag_cta.g_ctas.cod_oficina;
      if pag_cta.fu_obt_cod_error() <> 0 then
         v_cod_respuesta := '014';
         v_msj_respuesta := 'Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error();
      end if;
      if v_cod_respuesta = '000' then
         --solo si afecta limite
         if v_afe_limite <> 'S' THEN
            v_lim_utilizado := 0;
         else
            --WA:05/09/2013, Si es Compra
            --O es Venta y se cobro con cheque cargo otros bancos debe afectar
             if v_cod_mad_operacion=71  or nvl(p_cheque,0) > 0 then
               if v_cod_mad_operacion=71  then
                  v_mto_lim:=  p_importe;
                  v_cod_moneda_lim:=p_cod_moneda ;
               else
                  v_mto_lim:=  p_cheque;
                  v_cod_moneda_lim:=v_mon_local;
               end if;
             else
               v_lim_utilizado := 0;
               v_afe_limite :='N';
             end if;
            --Si sigue siendo 'S' se sigue la operativa normal
            IF v_afe_limite='S' then
                --si moneda de la operacion diferente al limite convertir
                if v_cod_moneda_lim= v_mon_local then
                  v_lim_utilizado:=round(v_mto_lim/v_cotizacion);
                elsif v_cod_moneda_lim <> v_mon_fuerte then
                  v_lim_utilizado:=pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda_lim,v_mon_fuerte,v_mto_lim,p_cotizacion);--para q busque la correspondiente
                else
                  v_lim_utilizado:= v_mto_lim;
                end if;



                if nvl(pag_cta.g_ctas.sal_disponible,0) - v_lim_utilizado < 0 then --si se va a neg supero el limite
                   v_aut_limite := 'S';
    
                    v_msj_limite := v_msj_limite || 'Necesita autorizacion por superar el limite de '||pag_cta.g_ctas.sal_total||' '
                                                 ||v_cod_moneda_lim||' de la cta. de cambios '||v_cta_cambios||'. '||v_des_operacion||' Nro. '
                                                 ||v_nro_operacion||' de '||v_mto_lim||' '||v_mon_fuerte||'.';
                end if;
            end if;
         end if;
      end if;
   end if;
   --> Verificar si el Usuario necesita autorizacion por superar monto p/ Operaciones de Cambios .-
   If v_cod_respuesta = '000' Then
     if p_cod_moneda != v_mon_fuerte then
       v_monto := pal_cam.FU_CON_MON_A_MONEDA(P_COD_MONEDA, V_MON_FUERTE, P_IMPORTE, P_COTIZACION);
     else
       v_monto := P_IMPORTE;
     end if;
     if v_monto > fug_obt_mto_maximo(USER, V_MON_FUERTE,7) then
       v_aut_monto := 'S';
       v_est_mvto  := 'X';
       v_msj_monto := v_msj_monto||'Necesita autorizacion. Excede USD '||v_monto||' al limite de USD '||fug_obt_mto_maximo(USER, V_MON_FUERTE,7)
                                 ||' establecido al Usuario '||USER||' para operaciones de Cambios en el Dia.'||'~'||'!';
      end if;
    End If;

   if v_cod_respuesta = '000' then
      if v_aut_cotizacion ='S' or v_aut_limite ='S' or v_aut_monto = 'S' OR v_aut_lim_var = 'S' then
         v_est_mvto_resto :='P';
      end if;
   end if;
   if v_cod_respuesta = '000' then
      if p_cod_banco is not null /*and p_nro_cheque is not null*/ then
         --determinar si el banco es local o extranjero
         begin
           select ubicacion, descripcion
             into v_ubi_banco, v_des_banco
            from ge_bancos
            where cod_banco = p_cod_banco
              and estado = 'A';
              --and cod_banco <> fug_obt_cod_banco;  se abre para cheq nstro bco
            if p_cod_tip_operacion = 18 then --compra de cheque
               if p_cod_banco = fug_obt_cod_banco then -- no puede ser nuestro bco
                  v_cod_respuesta := '001'; -- error
                  v_msj_respuesta := 'ERROR: No se puede Comprar Cheque de Nuestro Bco';
               end if;
            end if;
         exception
            when no_data_found then
              v_cod_respuesta := '001'; -- error
              v_msj_respuesta := 'ERROR: Codigo de Banco inexistente.';
            when others then
              v_cod_respuesta := '001'; -- error
              v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
         end;
         --obtiene retencion
         begin
           if p_cod_tip_operacion = 18 then --compra de cheque
             pal_cam.pr_obt_retencion(p_cod_tip_operacion, nvl(p_cod_banco,1), null,
                    p_cod_moneda, v_cod_oficina,v_COD_RETENCION, v_FEC_FIN_RETENCION);
             v_tip_retencion := v_cod_retencion;
           end if;
         exception
            when others then
               v_cod_respuesta := '001';
               v_msj_respuesta := 'ERROR: Problema con la retencion, '||substr(sqlerrm,1,400);
         end;
      end if;
   end if;

    -- Agregado en fecha 02/08/2013 por MS
    -- CNFLIMVAR-65 --
    BEGIN
        IF v_cod_respuesta = '000' THEN
            lp_controlar_limites_var();
        END IF;
    END;

   --genera movimiento principal
   if v_cod_respuesta = '000' then
     r_gmovi.cod_usuario     := user;
     r_gmovi.hora            := v_hora;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.fec_valor       := v_fec_actual;
     r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
     r_gmovi.cod_mod_padre   := 7;
     r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
     r_gmovi.cod_modulo      := 7;
     r_gmovi.cod_modalidad   := v_cod_mad_operacion;
     r_gmovi.cod_oficina     := v_COD_OFICINA;
     r_gmovi.nro_caja        := p_nro_caja;
     r_gmovi.NRO_DOCUMENTO2 := v_nro_referencia;
     r_gmovi.NRO_DOCUMENTO4 := v_cod_transaccion;--transac.de caja para poder autorizar
     r_gmovi.COD_REF_CAMBIO := v_cod_tip_referencia;

     v_nro_secuencia         := v_nro_secuencia + 1;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     r_gmovi.cod_moneda      := p_cod_moneda;
     r_gmovi.cod_transaccion := v_cod_tra_operacion;
     r_gmovi.monto           := p_IMPORTE;
     r_gmovi.nro_documento   := v_nro_operacion;
     r_gmovi.cod_ofi_origen  := v_cod_oficina;
     r_gmovi.emi_aviso       := v_emi_aviso;
     r_gmovi.concepto        := substr(nvl(v_nom_completo,p_nombre),1,35);
     if v_aut_cotizacion = 'S' or v_aut_monto = 'S' or v_aut_lim_var = 'S' then
        r_gmovi.estado       := v_est_mvto;
     else
        r_gmovi.estado       := v_est_mvto_resto; --es P si alguno pide aut,sino es N
     end if;
     r_gmovi.reversado       := 'N';
     if v_cod_mad_operacion = 71 then --compra
       r_gmovi.tip_mov_rubro := 'D';
       if p_cod_tip_operacion in (18) then --compra de cheque
          r_gmovi.NRO_DOCUMENTO3  := p_nro_cheque;
          r_gmovi.cod_banco       := p_cod_banco;
          if nvl(v_ubi_banco,'L') = 'L' then --si no cargo banco se asume local
             v_tip_monto := 'S';--cheque para afectar cj_controles
             r_gmovi.cod_transaccion := 632;
          else
             v_tip_monto := 'X'; --plaza ext.
             r_gmovi.cod_transaccion := 633;
          end if;
          if v_cod_retencion is null then
             --obtiene retencion
             pal_cam.pr_obt_retencion(p_cod_tip_operacion, nvl(p_cod_banco,1), null,
                    p_cod_moneda, v_cod_oficina,v_COD_RETENCION, v_FEC_FIN_RETENCION);
             v_tip_retencion := v_cod_retencion;
          end if;
          r_gmovi.cod_retencion     := v_cod_retencion;
          r_gmovi.fec_fin_retencion := v_fec_fin_retencion;
       else
          v_tip_monto := 'E'; --efectivo
       end if;
     else --venta
       if p_cod_tip_operacion = 26 then
          v_tip_monto := 'E'; --efectivo
       end if;
       r_gmovi.tip_mov_rubro := 'C';
       if v_tip_aplicacion = 'C' then --afecta cuenta cliente
          r_gmovi.nro_cuenta      := p_cta_cliente; --credito cta
          r_gmovi.cod_modulo      := v_cod_mod_cuenta;
          r_gmovi.cod_modalidad   := v_cod_mad_cuenta;
          r_gmovi.cod_oficina     := v_ofi_cta_cliente;
          r_gmovi.cod_transaccion := 602; --credito cta
       end if;
     end if;
     if v_tip_aplicacion in ('B','A') then --afecta cta.ctable o cta corresponsal
        r_gmovi.cod_rubro    := v_cod_rubro;
     end if;
     r_gmovi.cotizacion         := p_cotizacion;
     r_gmovi.mto_equ_local      := round(P_IMPORTE * P_COTIZACION,v_redondeo_ml);
     r_gmovi.cod_bco_central    := v_cod_ope_bcp;
     r_gmovi.cod_tip_ope_cambio := p_cod_tip_operacion;
     r_gmovi.cod_persona        := fue_obt_cod_persona(p_nro_documento); --CRO-JM-01/06/2015: Se agrega la funcion para obtener codigo persona.-

     -- verifico los decimales del importe y autorizacion -- solo por el credito
     --si es venta se hace x el principal, si es compra se hace x la forma de pago
     if v_cod_mad_operacion = 72 and v_tip_aplicacion <> 'C' then
        if v_tip_monto not in ('Z') then --no afecta
           v_msj_respuesta := fuj_val_importe(r_gmovi.tip_mov_rubro,v_tip_monto,p_cod_moneda,p_importe,245);
           if v_msj_respuesta is not null then
              v_cod_respuesta := '005';  -- error
           end if;
        end if;
     end if;

     if v_cod_respuesta = '000' then
        --genera el movimiento
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);

        --si es compra de cheque se envia cheque
        if v_tip_monto not in ('Z') then --no afecta
           lp_gen_transaccion(r_gmovi.tip_mov_rubro,
                              v_tip_monto, -- Efectivo o Cheque
                              r_gmovi.cod_moneda,
                              r_gmovi.monto,
                              r_gmovi.nro_secuencia);
        end if;
     end if;
   end if;
   r_gmovi.cod_tip_ope_cambio := null;
   r_gmovi.cod_rubro          := null;
   r_gmovi.NRO_DOCUMENTO3     := null;
   r_gmovi.NRO_DOCUMENTO2     := null;
   r_gmovi.cod_banco          := null;
   r_gmovi.cod_retencion      := null;
   r_gmovi.fec_fin_retencion  := null;
   v_cod_retencion            := null;
   v_fec_fin_retencion        := null;
   r_gmovi.nro_cuenta         := null;
   r_gmovi.cod_modulo      := 7;
   r_gmovi.cod_modalidad   := v_cod_mad_operacion;
   r_gmovi.cod_oficina     := v_COD_OFICINA;


   --actualiza la posicion si corresponde
   if v_cod_respuesta = '000' then
     if v_est_mvto = 'N' and v_est_mvto_resto = 'N' then --si ninguno queda pendiente
        PAL_CAM.PR_ACT_POSICIONES(p_cod_tip_operacion,p_cod_moneda,pal_cam.fu_obt_ofi_cambio(v_cod_oficina),
                            p_importe,round(P_IMPORTE * P_COTIZACION,v_redondeo_ml),v_cod_ope_bcp);
     end if;
   end if;

   --actualizacion de limite, solo si afecta recupera retencion
   if v_cod_respuesta = '000' then
      begin
        --wa:06/09/2013 Si afecta Limite, se hace Update
        if v_afe_limite ='S' then
            select estado, cod_oficina
              into v_est_cta, v_cod_ofi_cta
              from lc_cta_cambios
             where nro_cuenta = v_cta_cambios
               for update of estado;
            update lc_cta_cambios
               set mto_utilizado = nvl(mto_utilizado,0) + nvl(v_lim_utilizado,0),
                   fec_ult_movimiento = v_fec_actual,
                   estado = decode(estado,'A','N',estado),
                   fec_cam_estado =decode(estado,'A',v_fec_actual,fec_cam_estado)
             where lc_cta_cambios.nro_cuenta = v_cta_cambios;
               --WA:11/09/2013 Si es venta y paga en cheque o es Cpra cheque cargo Otros
             if v_cod_mad_operacion=71  or nvl(p_cheque,0) > 0 then
                 if nvl(p_tip_retencion,1) = 1 then
                   v_cod_tra_cheque := 607; --- Cheques
                elsif p_tip_retencion = 2 then
                   v_cod_tra_cheque := 610; --- Cheques
                elsif p_tip_retencion = 3 then
                   v_cod_tra_cheque := 632; --- Cheques
                 end if;
                --obtiene retencion
               if v_cod_mad_operacion=71 then
                  pal_cam.pr_obt_retencion(p_cod_tip_operacion, nvl(p_cod_banco,1), null,
                      v_mon_fuerte, v_cod_oficina,v_COD_RETENCION, v_FEC_FIN_RETENCION);
               ELSE
               --****************
                  pag_cta.pr_obt_retencion(v_fec_actual, null, 7, v_cod_mad_operacion, v_cod_tra_cheque ,
                  v_mon_local, v_COD_RETENCION, v_FEC_FIN_RETENCION);
               END IF;
           end if;
       end if;
        --genera movimientos
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_modulo      := 7;
        r_gmovi.cod_modalidad   := 70;
        r_gmovi.cod_oficina     := v_cod_ofi_cta;
        r_gmovi.cod_moneda      := v_mon_fuerte;
        r_gmovi.cod_transaccion := 760;
        r_gmovi.monto           := v_lim_utilizado;
        r_gmovi.nro_documento   := v_nro_operacion;
        if v_cod_persona is not null then --persona existente
           r_gmovi.NRO_DOCUMENTO2  := v_cod_persona;
        else
           r_gmovi.REFERENCIA := substr(p_nro_documento,1,20);
        end if;
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.emi_aviso       := v_emi_aviso;
        r_gmovi.concepto        := nvl(substr(nvl(v_nom_completo,p_nombre),1,35),'Operacion Cambios Limite');
        if v_afe_limite = 'S' and v_aut_limite = 'S' then
           r_gmovi.estado       := 'X';
        else
           r_gmovi.estado       := v_est_mvto_resto;
        end if;
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.nro_cuenta      := v_cta_cambios;
        r_gmovi.tip_mov_rubro   := null;
        if p_cod_moneda <> v_mon_fuerte then
         r_gmovi.cotizacion   := pag_gen.fu_obt_cotizacion(v_mon_fuerte);--(r_gmovi.mto_equ_local/v_lim_utilizado);--p_cotizacion;--cotizacion del limite en la moneda fuerte
      else
          r_gmovi.cotizacion := p_cotizacion;
      end if;
        r_gmovi.mto_equ_local   := ROUND(NVL(v_lim_utilizado,0)*r_gmovi.cotizacion,v_redondeo_ml);
        r_gmovi.cod_bco_central := v_cod_ope_bcp;
        r_gmovi.COD_RETENCION   := v_COD_RETENCION;
        r_gmovi.FEC_FIN_RETENCION:= v_FEC_FIN_RETENCION;
        r_gmovi.cod_tip_ope_cambio:= null;
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        --movimiento x el cambio de estado de la cuenta si corresponde

        if v_est_cta = 'A' then
          v_nro_secuencia := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia  := v_nro_secuencia;
          r_gmovi.cod_modulo      := 7;
          r_gmovi.cod_modalidad   := 70;
          r_gmovi.cod_oficina     := v_cod_ofi_cta;
          r_gmovi.cod_moneda      := v_mon_fuerte;
          r_gmovi.fec_valor       := v_fec_actual;
          r_gmovi.cod_tra_padre   := 401;
          r_gmovi.cod_mod_padre   := 7;
          r_gmovi.cod_mad_padre   := 70;
          r_gmovi.cod_transaccion := 401;
          r_gmovi.monto           := null;
          r_gmovi.nro_documento   := null;
          r_gmovi.NRO_DOCUMENTO2  := null;
          r_gmovi.cod_ofi_origen  := v_cod_oficina;
          r_gmovi.emi_aviso       := v_emi_aviso;
          r_gmovi.concepto        := 'Cambio de Estado ';
          r_gmovi.estado          := 'N';
          r_gmovi.est_cuenta      := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.cod_rubro       := NULL;
          r_gmovi.nro_cuenta      := v_cta_cambios;
          r_gmovi.tip_mov_rubro   := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.mto_equ_local   := null;
          r_gmovi.cod_bco_central := null;
          r_gmovi.COD_RETENCION   := null;
          r_gmovi.FEC_FIN_RETENCION :=null;
          r_gmovi.COD_REF_CAMBIO   := null;
          r_gmovi.cod_tip_ope_cambio := null;
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        end if;
      EXCEPTION
        WHEN OTHERS THEN
          v_cod_respuesta := '019';
          v_msj_respuesta := 'Actualiza limite. '||sqlerrm;
      END;
   end if;--limite

   r_gmovi.nro_cuenta       := null;
   r_gmovi.est_cuenta       := null;
   r_gmovi.COD_RETENCION    := null;
   r_gmovi.FEC_FIN_RETENCION:= null;
   r_gmovi.cotizacion       := null;
   r_gmovi.mto_equ_local    := null;
   r_gmovi.cod_bco_central  := null;
   r_gmovi.REFERENCIA       := null;
   r_gmovi.NRO_DOCUMENTO2   := v_nro_referencia;
   r_gmovi.COD_REF_CAMBIO   := v_cod_tip_referencia;
   r_gmovi.cod_modulo       := 7;
   r_gmovi.cod_mod_padre    := 7;
   r_gmovi.cod_modalidad    := v_cod_mad_operacion;
   r_gmovi.cod_oficina      := v_cod_oficina;
   r_gmovi.cod_tra_padre    := v_cod_tra_operacion;
   r_gmovi.cod_mad_padre    := v_cod_mad_operacion;

   -- si necesita autorizacion generar el registro
   if v_cod_respuesta = '000' then
      --> Inserta Autorizacion por Cotizacion fuera de Rango.-
      IF v_aut_cotizacion = 'S' THEN
         --monto se convierte a moneda fuerte
         if p_cod_moneda <> v_mon_fuerte then
           v_monto := pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,v_mon_fuerte,p_importe,p_cotizacion);--para q busque la correspondiente
         else
           v_monto:= p_importe;
         end if;
         begin
           INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                      FECHA               ,
                                      HORA                ,
                                      COD_USUARIO         ,
                                      MENSAJE             ,
                                      ESTADO              ,
                                      RESPUESTA           ,
                                      MTO_MON_FUERTE      ,
                                      TIP_AUTORIZACION    )
                                VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                      v_fec_actual        ,
                                      v_hora              ,
                                      v_cod_usuario       ,
                                      v_msj               ,
                                      'S'                 ,
                                      'P'                 ,
                                      v_monto             ,
                                      'C'                 );
             --en el trigger se envia mail al autorizador
         exception
            when others then
                v_cod_respuesta := '017';
                v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
         end;
      END IF;

      --> Inserta Autorizacion por Limites VaR.-
      IF v_aut_lim_var = 'S' THEN
         --monto se convierte a moneda fuerte
         if p_cod_moneda <> v_mon_fuerte then
           v_monto := pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,v_mon_fuerte,p_importe,p_cotizacion);--para q busque la correspondiente
         else
           v_monto:= p_importe;
         end if;
         begin
           INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                      FECHA               ,
                                      HORA                ,
                                      COD_USUARIO         ,
                                      MENSAJE             ,
                                      ESTADO              ,
                                      RESPUESTA           ,
                                      MTO_MON_FUERTE      ,
                                      TIP_AUTORIZACION    )
                                VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                      v_fec_actual        ,
                                      v_hora              ,
                                      v_cod_usuario       ,
                                      v_msj_lim_var||' Tipo operacion: '||p_cod_tip_operacion||' - Nro. '||v_nro_operacion,
                                      'S'                 ,
                                      'P'                 ,
                                      v_monto             ,
                                      'V'                 ); -- limites var
             --en el trigger se envia mail al autorizador
         exception
            when others then
                v_cod_respuesta := '017';
                v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
         end;
      END IF;


      --> Inserta Autorizacion por Superar el Limite de la Cuenta de Cambios.-
      IF v_cod_respuesta = '000' and v_aut_limite = 'S' THEN
         --monto se convierte a moneda fuerte
         if p_cod_moneda <> v_mon_fuerte then
           --wa:19/09/2013 Se debe enviar solo lo que se retiene(v_mto_lim)
           v_monto := pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,v_mon_fuerte,v_mto_lim/*p_importe*/,p_cotizacion);--para q busque la correspondiente
         else
           v_monto:= v_mto_lim;--p_importe;
         end if;
         begin
           INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                      FECHA               ,
                                      HORA                ,
                                      COD_USUARIO         ,
                                      MENSAJE             ,
                                      ESTADO              ,
                                      RESPUESTA           ,
                                      MTO_MON_FUERTE      ,
                                      TIP_AUTORIZACION    )
                                VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                      v_fec_actual        ,
                                      v_hora              ,
                                      v_cod_usuario       ,
                                      v_msj_limite        ,
                                      'S'                 ,
                                      'P'                 ,
                                      v_monto             ,
                                      'L'                 );
             --en el trigger se envia mail al autorizador
         exception
            when others then
                v_cod_respuesta := '017';
                v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
         end;
      END IF;

      --> Inserta Autorizacion por Superar Monto permitido al usuario p/ Operaciones de Cambios en el Dia.-
      IF v_cod_respuesta = '000' and v_aut_monto = 'S' THEN
         if p_cod_moneda <> v_mon_fuerte then
           v_monto := pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,
                                                 v_mon_fuerte ,
                                                 p_importe    ,
                                                 p_cotizacion);
         else
           v_monto:= p_importe;
         end if;
         begin
           INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                      FECHA               ,
                                      HORA                ,
                                      COD_USUARIO         ,
                                      MENSAJE             ,
                                      ESTADO              ,
                                      RESPUESTA           ,
                                      MTO_MON_FUERTE      ,
                                      TIP_AUTORIZACION    )
                                VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                      v_fec_actual        ,
                                      v_hora              ,
                                      v_cod_usuario       ,
                                      v_msj_monto               ,
                                      'S'                 ,
                                      'P'                 ,
                                      v_monto             ,
                                      'M'                 );
         exception
            when others then
                v_cod_respuesta := '017';
                v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
         end;
      END IF;
   end if;

   --gastos
   if v_cod_respuesta = '000' then
     if nvl(v_mto_cargo1,0) > 0 or  nvl(v_mto_cargo2,0) > 0 or nvl(v_mto_cargo3,0)>0 then
         --movimiento x cada uno de los 3 cargos posibles
        for i in 1..3 loop
           if i =1 THEN    /* Por valor del gasto 1 */
             v_mov_mto_cargo    := round(v_mto_cargo1,v_redondeo_ml);
             v_mov_cod_tra_cargo:= v_cod_tra_cargo1;
             v_mov_cod_tasa     := v_cod_tasa1;
             v_mov_val_tasa     := v_val_tasa1;
           elsif i = 2 THEN      /* Por valor del gasto 2 */
             v_mov_mto_cargo    := v_mto_cargo2;
             v_mov_cod_tra_cargo:= round(v_cod_tra_cargo2,v_redondeo_ml);
             v_mov_cod_tasa     := v_cod_tasa2;
             v_mov_val_tasa     := v_val_tasa2;
           elsif i = 3  THEN      /* Por valor del gasto 3 */
             v_mov_mto_cargo    := round(v_mto_cargo3,v_redondeo_ml);
             v_mov_cod_tra_cargo:= v_cod_tra_cargo3;
             v_mov_cod_tasa     := v_cod_tasa3;
             v_mov_val_tasa     := v_val_tasa3;
           end if;
           --verificar si tienen impuestos asociados
           pal_cam.pr_obt_impuestos(v_mov_cod_tra_cargo, v_cod_mad_operacion, v_mov_mto_cargo,
                v_cod_oficina, v_tra_impuesto, v_impuesto, v_cod_tasa, v_val_tasa);
           if v_impuesto is not null then
              --se desglosa el impuesto para los movimientos
              v_mov_mto_cargo := v_mov_mto_cargo - v_impuesto;
           end if;
           if v_mov_cod_tra_cargo is not null then
               -- Aumento la secuencia
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_mon_local;
              r_gmovi.cod_transaccion := v_mov_cod_tra_cargo;
              r_gmovi.monto           := v_mov_mto_cargo;
              r_gmovi.nro_documento   := v_nro_operacion;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := v_emi_aviso;
              r_gmovi.concepto        := 'Cargos de Cambios';
              r_gmovi.estado          := v_est_mvto_resto;
              r_gmovi.reversado       := 'N';
              r_gmovi.COD_TASA        := v_mov_cod_tasa;
              r_gmovi.VAL_TASA        := v_mov_val_tasa;
              r_gmovi.tip_mov_rubro   := null;
              r_gmovi.cod_tip_ope_cambio:=null;
              r_gmovi.cod_bco_central := v_cod_ope_bcp;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
               -- genero movimiento x el impuesto
               if v_impuesto is not null then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_transaccion := v_tra_impuesto;
                r_gmovi.monto           := v_impuesto;
                r_gmovi.COD_TASA        := v_cod_tasa;
                r_gmovi.VAL_TASA        := v_val_tasa;
                r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              END IF;
           end if;
       end loop;
       r_gmovi.cod_tasa     :=null;
       r_gmovi.val_tasa     :=null;
     end if;
   end if;

   --actualiza cuenta de arriba en venta de depositos
   if v_cod_respuesta = '000' then
      if v_cod_mad_operacion =72 and v_tip_aplicacion ='C' then  --venta
         --ojo si es P o N actualiza saldo credito, si es X no hace nada (se actualiza en la aprobacion)
         --si es X ver de actualizar en la aprobacion
         IF v_est_mvto ='N' then --si tiene aut.x limite o si es normal
            --actualiza sal_total,ver 2ult param(autorizacion y fec_ult_movimiento)
            PAG_CTA.PR_ACT_SAL_CTA(p_cta_cliente,v_cod_mad_cuenta,'C',
                                 v_fec_actual,v_hora,p_importe,0,0,null,'N');
             
             IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
               v_cod_respuesta := '023';
               v_msj_respuesta := 'Act.Sal. '||pag_cta.fu_obt_msj_error();
            END IF;
            --actualiza estado de la cta si corresponde
            IF v_est_ant_cta_cliente in ('I','A') THEN
               --ACTUALIZAR ESTADO A 'N'
               pag_cta.pr_set_variables(v_cod_usuario, v_fec_actual,
                                        v_cod_tra_operacion,
                                        'N',--estado mvto
                                        'N',--reversado
                                        v_nro_secuencia,
                                        v_est_cuenta, -- estado pasa a c
                                        v_cod_oficina,
                                        7,
                                        v_cod_mad_operacion);
               PAG_CTA.PR_ACT_ESTADO(p_cta_cliente,'N',v_fec_actual,v_hora,null,'S');--procesar
               v_nro_secuencia := v_nro_secuencia + 1;
               IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
                  v_cod_respuesta := '024';
                  v_msj_respuesta := 'Act.Est. '||v_est_cuenta||'*'||v_est_ant_cta_cliente||'*'||PAG_CTA.FU_OBT_COD_ERROR()||'*'||pag_cta.fu_obt_msj_error();
               END IF;
            END IF;
         END IF;--estado N
      end if;--compra / venta
   end if;

   --movimiento x la forma de pago:efectivo/credito en cuenta // cobro: efectivo/cheque
   if v_cod_respuesta = '000' then
      --solo compra tiene credito en cuenta
      if v_cod_mad_operacion =71 then
        if p_cta_credito is not null and nvl(p_mto_cuenta,0) >0 then
          --si el movimiento es pendiente en la aprobacion se acredita a la/s cuenta/s
          --entonces solo genera el movimiento, sino acredita
          --recuperar datos de la cta de cliente a acreditar
          pag_cta.pr_obt_cuenta(p_cta_credito);
          if v_est_mvto_resto ='P' then
            --generar movimiento
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
            r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
            r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
            r_gmovi.cod_moneda      := v_mon_local;
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_tra_padre   := v_cod_tra_operacion;--:AUXILIAR.SCR_CDTRAN1
            r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
            r_gmovi.cod_mod_padre   := 7;
            r_gmovi.cod_transaccion := 602; --credito cta cliente
            r_gmovi.monto           := p_mto_cuenta;
            r_gmovi.nro_documento   := v_nro_operacion;
            r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
            r_gmovi.cod_ofi_origen  := v_cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Operacion de Cambios-Credito Cta';
            r_gmovi.estado          := 'P';
            r_gmovi.est_cuenta      := null;
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := null;
            r_gmovi.nro_cuenta      := p_cta_credito;
            r_gmovi.tip_mov_rubro   := null;
            r_gmovi.cotizacion      := null; --pago es en moneda local
            r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
            r_gmovi.cod_tip_ope_cambio := 3;
            r_gmovi.COD_RETENCION   := null;
            r_gmovi.FEC_FIN_RETENCION := null;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
          else
            -- Actualiza la Cuenta Credito / Destino
            pag_cta.pr_act_operacion(p_cta_credito,
                           v_hora,--HORA
                           'C',
                           pag_cta.g_ctas.cod_moneda, --Moneda de la Operacion
                           p_mto_cuenta,
                           v_cod_tra_operacion,  -- COD_TRA_PADRE (Compra divisas en efectivo)
                           602,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                           v_nro_operacion, --nro_documento
                           null,       --COTIZACION, los pagos son en moneda local
                           v_cod_oficina,      --cod_ofi_origen
                           7,                --cod_mod_padre
                           v_cod_mad_operacion,--o abmc.modalidad       --cod_mad_padre
                           null,                       --cod_tasa
                           null,                       --val_tasa
                           'Operacion de Cambios-Credito Cta',
                           'S',                        --emi_aviso
                           v_nro_secuencia,
                           v_fec_actual);
            if pag_cta.fu_obt_cod_error() <> 0 then
              v_cod_respuesta := '024';
              v_msj_respuesta := 'Credito. '||pag_cta.fu_obt_msj_error();
            end if;
            --actualizar el movimiento con el tip_ope_cambio
            begin
              update ge_movimientos
                 set cod_tip_ope_cambio = 3,
                     nro_documento2 = v_nro_referencia,
                     cod_ref_cambio = v_cod_tip_referencia
               where fecha =v_fec_actual
                 and hora = v_hora
                 and cod_usuario =v_cod_usuario
                 and nro_cuenta = p_cta_credito
                 and cod_tra_padre = v_cod_tra_operacion
                 and cod_mod_padre = 7
                 and cod_mad_padre = v_cod_mad_operacion
                 and cod_modulo = pag_cta.g_ctas.cod_modulo
                 and cod_modalidad = pag_cta.g_ctas.cod_modalidad
                 and cod_moneda =v_mon_local
                  and monto = p_mto_cuenta;
            exception
              when others then
                v_cod_respuesta := '025';
                v_msj_respuesta := 'Act.Mvto.Credito. '||substr(sqlerrm,1,400);
            end;
          end if;
        end if;--cta cliente
      end if;--compra
     r_gmovi.cod_modulo      := 7;
     r_gmovi.cod_modalidad   := v_cod_mad_operacion;
     r_gmovi.cod_oficina     := v_COD_OFICINA;
     r_gmovi.nro_cuenta      := null;
     r_gmovi.est_cuenta      := null;

   end if;--v_cod_respuesta

   --movimiento x el efectivo
   if v_cod_respuesta = '000' then
      if nvl(p_efectivo,0) > 0 then
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.cod_oficina     := v_cod_oficina;
         r_gmovi.cod_moneda      := v_mon_local;
         if v_cod_mad_operacion =71 then
             r_gmovi.cod_tip_ope_cambio := 1;
            r_gmovi.cod_transaccion    := 740;
            v_tip_mov_rubro            := 'C';
            r_gmovi.monto              := p_efectivo; --el total si es compra//ya no,puede ser contra cred en cta tambien
         else
            r_gmovi.cod_tip_ope_cambio := 6;
            r_gmovi.cod_transaccion    := 840;
            v_tip_mov_rubro            := 'D';
            r_gmovi.monto              := p_efectivo; --solo la porcion efectivo si es venta
         end if;
         r_gmovi.nro_documento   := v_nro_operacion;
         r_gmovi.cod_ofi_origen  := v_cod_oficina;
         r_gmovi.emi_aviso       := v_emi_aviso;
         r_gmovi.concepto        := 'Operacion de Cambios Caja';
         r_gmovi.estado          := v_est_mvto_resto;
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := NULL;
         r_gmovi.tip_mov_rubro   := null;
         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         r_gmovi.cod_bco_central := v_cod_ope_bcp;

         -- verifico los decimales del importe y autorizacion -- solo por el credito
         --si es venta se hace x el principal, si es compra se hace x la forma de pago
         if v_cod_mad_operacion = 71 then --compra
           v_msj_respuesta := fuj_val_importe(v_tip_mov_rubro,'E',v_mon_local,r_gmovi.monto,245);
           if v_msj_respuesta is not null then
              v_cod_respuesta := '005';  -- error
           end if;
         end if;

         if v_cod_respuesta = '000' then
            --genera movimiento
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);

            lp_gen_transaccion(v_tip_mov_rubro,
                               'E', -- fijo Efectivo
                               r_gmovi.cod_moneda,
                               r_gmovi.monto,
                               r_gmovi.nro_secuencia);
         end if;
      end if;
   end if;

   --movimiento x pago en cheque otros bcos si hubiera
   if v_cod_respuesta = '000' then
      --solo si es venta
      if v_cod_mad_operacion =72 then
         if nvl(p_cheque,0) > 0 then --si hay monto cheque
            v_COD_RETENCION := null;
            v_FEC_FIN_RETENCION:= null;
            --depende del tipo de retencion
            if nvl(p_tip_retencion,1) = 1 then
               v_cod_tra_cheque := 607; --- Cheques
               v_tip_monto := 'O';
            elsif p_tip_retencion = 2 then
               v_cod_tra_cheque := 610; --- Cheques
               v_tip_monto := 'T';
            elsif p_tip_retencion = 3 then
               v_cod_tra_cheque := 632; --- Cheques
               v_tip_monto := 'S';
            end if;
            --obtiene retencion
            pag_cta.pr_obt_retencion(v_fec_actual, null, 7, v_cod_mad_operacion, v_cod_tra_cheque ,
                            v_mon_local, v_COD_RETENCION, v_FEC_FIN_RETENCION);
             if pag_cta.fu_obt_cod_error() <> 0 then
                v_cod_respuesta := '030';
                v_msj_respuesta := 'Ret.Chq '||pag_cta.fu_obt_msj_error();
             end if;

            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_moneda      := v_mon_local;
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
            r_gmovi.cod_mod_padre   := 7;
            r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
            r_gmovi.cod_transaccion := v_cod_tra_cheque; --- Cheques
            r_gmovi.monto           := p_cheque;
            r_gmovi.nro_documento   := v_nro_operacion;
            r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
            r_gmovi.cod_ofi_origen  := v_cod_oficina;
            r_gmovi.emi_aviso       := v_emi_aviso;
            r_gmovi.concepto        := 'Operacion de Cambios ';
            r_gmovi.estado          := v_est_mvto_resto;--'J'; --- Pendiente de pasar por caja
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.nro_cuenta      := null;
            r_gmovi.tip_mov_rubro   := null;--o D
            r_gmovi.cotizacion      := null;--v_cotizacion;forma de pago siempre en gs
            r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
            r_gmovi.COD_RETENCION   := v_COD_RETENCION;
            r_gmovi.FEC_FIN_RETENCION  := v_FEC_FIN_RETENCION;
            r_gmovi.cod_tip_ope_cambio := 7;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            lp_gen_transaccion('D',--mvto deb
                               v_tip_monto, -- cheque
                               r_gmovi.cod_moneda,
                               r_gmovi.monto,
                               r_gmovi.nro_secuencia);
         end if;
      end if;
   end if;

   --movimiento x pago en cheque nuestro bco si hubiera
   if v_cod_respuesta = '000' then
      --solo si es venta
      if v_cod_mad_operacion =72 then
         if nvl(p_che_ntro_bco,0) > 0 then --si hay monto cheque
            v_COD_RETENCION := null;
            v_FEC_FIN_RETENCION:= null;
            --obtiene retencion
            pag_cta.pr_obt_retencion(v_fec_actual, null, 7, v_cod_mad_operacion, 606 ,
                            v_mon_local, v_COD_RETENCION, v_FEC_FIN_RETENCION);
             if pag_cta.fu_obt_cod_error() <> 0 then
                v_cod_respuesta := '030';
                v_msj_respuesta := 'Ret.Chq.Ntro. '||pag_cta.fu_obt_msj_error();
             end if;

            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_moneda      := v_mon_local;
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
            r_gmovi.cod_mod_padre   := 7;
            r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
            r_gmovi.cod_transaccion := 606; --- Cheques
            r_gmovi.monto           := p_che_ntro_bco;
            r_gmovi.nro_documento   := v_nro_operacion;
            r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
            r_gmovi.cod_ofi_origen  := v_cod_oficina;
            r_gmovi.emi_aviso       := v_emi_aviso;
            r_gmovi.concepto        := 'Operacion de Cambios ';
            r_gmovi.estado          := v_est_mvto_resto;--'J'; --- Pendiente de pasar por caja
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.nro_cuenta      := null;
            r_gmovi.tip_mov_rubro   := null;--o D
            r_gmovi.cotizacion      := null;--v_cotizacion;forma de pago siempre en gs
            r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
            r_gmovi.COD_RETENCION   := v_COD_RETENCION;
            r_gmovi.FEC_FIN_RETENCION  := v_FEC_FIN_RETENCION;
            r_gmovi.cod_tip_ope_cambio := 7;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            lp_gen_transaccion('D',--mvto deb
                               'C', -- cheque
                               r_gmovi.cod_moneda,
                               r_gmovi.monto,
                               r_gmovi.nro_secuencia);
         end if;
      end if;
   end if;
   
  --Si esta todo correcto y no es Cliente inserta en la tabla ge_reg_mov_seprelad
   if v_cod_respuesta = '000' then
       v_cliente := fug_es_cliente(v_cod_per_2);
       if v_cliente = 'N' then
         PRL_INS_REG_MOV_SEPRELAD(v_fec_actual,v_hora,v_cod_usuario,1,p_IMPORTE,p_cod_moneda,v_cod_oficina,
                                  v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_tra_operacion,7,v_cod_mad_operacion,
                                  round(P_IMPORTE * P_COTIZACION,v_redondeo_ml),p_nro_caja,p_cotizacion,v_nro_operacion,
                                  v_cod_transaccion,v_cod_per_2);
       end if;
   end if;
   
   if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
     -- CRO-JM-03/2015: CROGEFIT-3. Cuando se trate de compra/venta de efectivo utilizaremos la cuenta de cambio, sino utilizaremos la cuenta del cliente.
         if p_cta_cliente is not null then
            v_nro_cuenta := p_cta_cliente;
         else
            v_nro_cuenta := v_cta_cambios;
         end if;
      --imprimir comprobante de operaciones
      if v_est_mvto_resto <> 'P' then --normal
         -- veo si se detallo el cheque, sino se debe entrar despues a detallar
         --puede ser compra de cheque, o una venta q se cobra en cheque
          if p_cod_banco is not null and p_nro_cheque is not null then
             --si es compra se envia el monto de la operacion
             if v_cod_mad_operacion = 71 then
                v_mto_cheque := p_importe;
                v_cod_retencion := v_tip_retencion;--compra
             else--venta, solo si tiene monto
                v_mto_cheque := p_cheque;
                v_cod_retencion := p_tip_retencion;--parametro
             end if;
             if p_cod_banco =  fug_obt_cod_banco then --
                v_cod_respuesta := '001'; -- error
                v_msj_respuesta := 'ERROR: Banco no puede ser '||p_cod_banco;
             end if;

             if v_cod_respuesta = '000' then
                --NULL;
                --si hay monto
                if v_mto_cheque > 0 then
                   --si el banco es local -> 133
                    if v_ubi_banco = 'L' then
                       --solo si la retencion es > 1
                       if v_cod_retencion > 1 then
                          v_msj_salida := fuj_pro_transaccion_133(p_nro_operacion,
                                                               p_nro_caja,
                                                               v_nro_operacion,
                                                               v_cod_retencion,
                                                               p_cod_banco,
                                                               p_nro_cheque,
                                                               v_mto_cheque);
                     
                          if v_msj_salida NOT LIKE '%~000~%' THEN
                             return v_msj_salida;
                          END IF;
                       end if;
                   else  --si es extranjero -> 134, solo en compra se puede dar plaza ext.
                      v_msj_salida := fuj_pro_transaccion_134(p_nro_operacion,
                                                           p_nro_caja,
                                                           v_nro_operacion,
                                                           p_cod_banco,
                                                           v_des_banco,
                                                           p_nro_cheque,
                                                           v_mto_cheque);
                     
                      if v_msj_salida NOT LIKE '%~000~%' THEN
                         return v_msj_salida;
                      END IF;
                   end if;
                end if;
             else
               -- retorna error
               v_msj_salida := p_nro_operacion||'~'||
                               v_cod_respuesta||'~'||
                               v_msj_respuesta;
             end if;
          end if;
          if v_cod_respuesta = '000' then
             --cheque ntro banco
             --solo venta puede tener cheque nuestro bco
             if nvl(p_che_ntro_bco,0) > 0 and nvl(p_nro_che_ntro,0) > 0 and v_cod_mad_operacion = 72 then
                 --busco la cuenta de cc_chequeras
                begin
                  select nro_cuenta
                  into v_cta_cheque
                  from cc_chequeras
                  where p_nro_che_ntro between nro_che_inicial and nro_che_final;
                exception
                  when too_many_rows then
                    v_cod_respuesta := '001'; -- error
                    v_msj_respuesta := 'ERROR: Varios cheques encontrados';
                  when others then
                    v_cod_respuesta := '001'; -- error
                    v_msj_respuesta := 'ERROR: Recuperar Cheque '||sqlerrm;
                end;
                if v_cod_respuesta = '000' then
                    -- se detallo el cheque, se procesa el detalle del mismo
                    v_msj_salida := fuj_pro_transaccion_355(p_nro_operacion,
                                                         p_nro_caja,
                                                         v_nro_operacion,
                                                         p_nro_che_ntro,
                                                         v_cta_cheque, --cuenta
                                                         p_che_ntro_bco,
                                                         null, --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
                                                         pag_gen.FU_OBT_SIG_SEGUNDO(pag_gen.FU_OBT_SIG_SEGUNDO(v_hora)));
                   
                    if v_msj_salida NOT LIKE '%~000~%' THEN
                       return v_msj_salida;
                    END IF;
                else
                   --salir
                   v_msj_salida := p_nro_operacion||'~'||
                                   v_cod_respuesta||'~'||
                                   v_msj_respuesta;
                end if;
             end if;
         else
            --salir
             v_msj_salida := p_nro_operacion||'~'||
                             v_cod_respuesta||'~'||
                             v_msj_respuesta;
         end if;
         --imprimir comprobante
         begin
           select nvl(cli_frecuente,'N')
             into v_cli_frecuente
             from cr_inf_fondos
            where cod_persona = fue_obt_cod_persona(p_nro_documento);
         exception
           when no_data_found then
           null;
           when others then
           null;
         end;
         if v_cli_frecuente is null then
           v_cli_frecuente := 'N';
         end if;
         if v_cod_respuesta = '000' then
            --si la operacion es superior avisar q se imprima la declaracion x gestion
           
         -- CRO-JM-03/2015: CROGEFIT-3
          if fuj_ver_imp_formulario(v_nro_cuenta,
                                    fue_obt_cod_persona(p_nro_documento),
                                    pag_gen.fu_con_mon_a_moneda(p_cod_moneda,
                                                                pag_gen.fu_obt_mon_fuerte,
                                                                p_importe),
                                    v_cod_transaccion,
                                    v_mto_calculado) then
              if v_cli_frecuente = 'N' then -- Solo si no es cliente frecuente imprime.  V.O. 25/11/2009
               --si ingreso comprobante manual no debe imprimir comprobante
               /*if p_nro_comprobante is null then*/
                  v_cod_respuesta := 'IMP';
                  v_msj_respuesta := 'Operacion Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||v_nro_operacion||'~'||
                                   fuj_imp_comprobante_245(v_nro_operacion, v_cod_oficina, p_nro_caja,v_cod_mad_operacion)||
                                   fuj_imp_dec_jurada_40(v_fec_actual, v_hora, user, 1, v_mto_calculado,v_cod_transaccion);
                -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                        prj_ins_form_transacciones(v_nro_cuenta,
                                                   fue_obt_cod_persona(p_nro_documento),
                                                   v_cod_modulo,
                                                   v_cod_transaccion,
                                                   USER,
                                                   v_fec_actual,
                                                   v_hora,
                                                   pag_gen.fu_obt_mon_fuerte,
                                                   pag_gen.fu_con_mon_a_moneda(p_cod_moneda,
                                                                               pag_gen.fu_obt_mon_fuerte,
                                                                               p_importe),
                                                   'S');
               
               -- retorno de la rutina de impresion
               v_msj_salida := p_nro_operacion||'~'||
                               v_cod_respuesta||'~'||
                               v_msj_respuesta;
              else
                v_cod_respuesta := 'IMP';
                v_msj_respuesta := 'Operacion Confirmada. Comprobante impreso.'||'~'||
                                   fuj_imp_comprobante_245(v_nro_operacion, v_cod_oficina, p_nro_caja,v_cod_mad_operacion);
                v_msj_salida := p_nro_operacion||'~'||
                                v_cod_respuesta||'~'||
                                v_msj_respuesta;
                  -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso aun:
                        prj_ins_form_transacciones(v_nro_cuenta,
                                                   fue_obt_cod_persona(p_nro_documento),
                                                   v_cod_modulo,
                                                   v_cod_transaccion,
                                                   USER,
                                                   v_fec_actual,
                                                   v_hora,
                                                   pag_gen.fu_obt_mon_fuerte,
                                                   pag_gen.fu_con_mon_a_moneda(p_cod_moneda,
                                                                               pag_gen.fu_obt_mon_fuerte,
                                                                               p_importe),
                                                   'N');
              end if;
            else
               --si ingreso comprobante manual no debe imprimir comprobante
               
               v_cod_respuesta := 'IMP';
               v_msj_respuesta := 'Operacion Confirmada. Comprobante impreso.'||'~'||
                                   fuj_imp_comprobante_245(v_nro_operacion, v_cod_oficina, p_nro_caja,v_cod_mad_operacion);
               
               -- retorno de la rutina de impresion
               v_msj_salida := p_nro_operacion||'~'||
                               v_cod_respuesta||'~'||
                               v_msj_respuesta;
                 -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso aun:
                        prj_ins_form_transacciones(v_nro_cuenta,
                                                   fue_obt_cod_persona(p_nro_documento),
                                                   v_cod_modulo,
                                                   v_cod_transaccion,
                                                   USER,
                                                   v_fec_actual,
                                                   v_hora,
                                                   pag_gen.fu_obt_mon_fuerte,
                                                   pag_gen.fu_con_mon_a_moneda(p_cod_moneda,
                                                                              pag_gen.fu_obt_mon_fuerte,
                                                                              p_importe),
                                                   'N');
            end if;
         else
           -- retorna error
           v_msj_salida := p_nro_operacion||'~'||
                           v_cod_respuesta||'~'||
                           v_msj_respuesta;
         end if;
      ELSE--operacion pendiente
       -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso aun:
        prj_ins_form_transacciones(v_nro_cuenta,
                                   fue_obt_cod_persona(p_nro_documento),
                                   v_cod_modulo,
                                   v_cod_transaccion,
                                   USER,
                                   v_fec_actual,
                                   v_hora,
                                   pag_gen.fu_obt_mon_fuerte,
                                   pag_gen.fu_con_mon_a_moneda(p_cod_moneda,
                                                                pag_gen.fu_obt_mon_fuerte,
                                                                p_importe),
                                   'N');
         IF v_aut_lim_var = 'S' THEN
             v_msj_respuesta := v_msj_lim_var;
         ELSE
             v_msj_respuesta := 'Operacion confirmada.Requiere Autorizacion';
         END IF;
         v_msj_salida := p_nro_operacion||'~'||
                        v_cod_respuesta||'~'||'!'|| --muestra en ventanita
                        nvl(v_msj_respuesta,'Operacion confirmada');
      end if;
   ELSE --ERROR--hubo problemas
      v_msj_salida := p_nro_operacion||'~'||
                      v_cod_respuesta||'~'||
                      nvl(v_msj_respuesta,SQLERRM);
   end if;
  return(v_msj_salida);
exception
   when others then
     v_cod_respuesta := '999';
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,SQLERRM);
     return(v_msj_salida);
end;
/
