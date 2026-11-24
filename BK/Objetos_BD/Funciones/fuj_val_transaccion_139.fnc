CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_139
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_DOCUMENTO IN VARCHAR2 default null
 ,P_NRO_CUENTA IN VARCHAR2 default null
 ,P_EFECTIVO IN VARCHAR2 default null
 ,P_CHQ_NBCO IN VARCHAR2 DEFAULT NULL
 ,P_CHQ_OBCO IN VARCHAR2 DEFAULT NULL
)
 RETURN VARCHAR2
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo         number(3) := 9;                         -- modulo Caja
  --v_cod_modalidad      number(3) := 91;                 -- modalidad Caja
  v_cod_transaccion    number(4) := 139;            -- cod de transaccion
  v_cod_usuario        varchar2(10) := upper(user); --usuario
  --
  v_msj_salida         varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta      varchar2(03) := '000'; -- sin errores
  v_error             number;
  v_msj_respuesta      varchar2(100) := 'OK'; -- sin errores
  v_can_campos         number(3) := 0;        -- cantidad de campos
  v_det_campos         varchar2(8000) := null;
  -- Datos de la caja
  v_fec_actual         date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hora               varchar2(8);
  v_cod_oficina        number(3);         -- Codigo de oficina
  v_estado             number(1);         -- estado de la caja
  v_fec_caja           date;              -- fecha de la caja
  v_sal_actual         number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta de préstamo
  v_mto_cobrado        number(18,2);      -- Mto cobrado (no se despliega)
  v_capital            number(18,2);      -- Capital (no se despliega )
  v_moratorio          number(18,2);      -- Mora s/Interés (DESPLIEGA : Mora s/interés )
  v_impuesto           number(18,2);      -- Total impuesto (DESPLIEGA : ley 125/91)
  v_cargos             number(18,2);      -- Total cargo (DESPLIEGA : Cargo + IVA )
  v_car_iva            number(18,2);
  v_iva                number(18,2);      -- Total cargo IVA  (no desp)
  v_tot_a_cobrar       number(18,2);      -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
  v_punitorio          number(18,2);      -- Total monto punitorio (DESPLIEGA : Punitorio)
  v_dia_mora           number(5); --Dias de mora

  v_tot_cre_cta        number(18,2);      -- Total pagado contra cuenta de ahorro
  v_tot_cre_cta_con    number(18,2);      -- Total pagado contra cuenta contable

  v_cod_tran_pend      number(4);    --- transaccion operacion pend.(efect 740 - cheq 607)
  v_monto_efectivo     number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque       number(18,2) :=0; --- importe pagado operacion pendiente cheque
  v_monto_cheque_n     number(18,2) :=0;
  v_tip_retencion      ge_movimientos.cod_retencion%type;
  /*CROCLIJUD-5*/
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial	 ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');

  cursor movimientos is --trae todos los mov.
    select cod_transaccion, monto
      from ge_movimientos
     where cod_tra_padre = v_cod_transaccion
       and fecha         = v_fec_actual
       and estado        = 'J'
       and hora          = v_hora
       and cod_ofi_origen = v_cod_oficina
       and reversado = 'N';

--- para activar campo cheque nuestro banco si tiene habilitado el modulo de cta.cte.
 r_opeven               ov_cta_vencidas%rowtype;
  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;
  v_lis_valores   varchar2(4000) := null;

  v_mov_existente number := 0;

Begin
-------------------------PROCESO PRINCIPAL-------------------------
  -- Inicializacion de la aplicacion y el modulo
  Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 if p_nro_documento is not null and p_nro_cuenta is null then
   v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');
   v_lis_valores   := fuj_pro_val_posibles(replace(v_val_posibles,'&NRO_DOCUMENTO',P_NRO_DOCUMENTO));
   begin
     select fuj_des_campo('NRO_CUENTA',a.nro_cuenta,v_lis_valores)
       into v_det_campos
      from ba_personas p, ov_cta_vencidas a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion= 'P'
        and b.cod_persona = p.cod_persona
        /*and a.nro_cuenta in
        (select nro_cuenta
           from ge_movimientos mov
          where mov.reversado = 'N'
              and mov.cod_tra_padre = 139
              and  (mov.fecha, mov.hora, mov.cod_usuario) in
              (select d.fecha, d.hora, d.cod_usuario
                 from ge_movimientos d
                where  d.estado = 'J'
                  and d.cod_tra_padre = 139))*/
         and p.nro_documento = p_nro_documento
      ORDER BY a.nro_cuenta;
   exception
      when no_data_found then
         v_det_campos := fuj_des_campo('NRO_CUENTA',' ',v_lis_valores);
      when too_many_rows then
         v_det_campos := fuj_des_campo('NRO_CUENTA',' ',v_lis_valores);
      when others then
         v_det_campos := fuj_des_campo('NRO_CUENTA',' ',v_lis_valores);
         v_cod_respuesta := '007';
         v_msj_respuesta := 'ERROR: Buscando cuenta '||sqlerrm;
   end;
    ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
    v_cod_persona := fue_obt_cod_persona(p_nro_documento);
    if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_nro_cuenta) Then
       v_cod_respuesta := '008';
       v_msj_respuesta := 'ERROR: Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico';
    End If;
   
 elsif p_nro_documento is null and p_nro_cuenta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cuenta.';
    v_det_campos := fuj_des_campo('NRO_CUENTA',NULL) ||
                    fuj_des_campo('DES_CUENTA',NULL) ||
                    fuj_des_campo('COD_MONEDA',NULL) ||
                    fuj_des_campo('CAPITAL',NULL)    ||
                    fuj_des_campo('MORATORIO',NULL)  ||
                    fuj_des_campo('PUNITORIO',NULL)  ||
                    fuj_des_campo('IMPUESTO',NULL)   ||
                    fuj_des_campo('CARGO_IVA',NULL)  ||
                    fuj_des_campo('EFECTIVO',NULL) ||
                    fuj_des_campo('CHQ_NBCO',NULL) ||
                    fuj_des_campo('CRE_CUENTA',NULL) ||
                    fuj_des_campo('CRE_CTA_CON',NULL)||
                    fuj_des_campo('COD_BANCO',NULL)  ||
                    fuj_des_campo('NRO_CHEQUE',NULL) ||
                    fuj_des_campo('IMP_CHEQUE',NULL) ||
                    fuj_des_campo('TOT_A_COBRAR',NULL)||
                    fuj_des_campo('GASTOS',NULL)||'2';
  else
    v_det_campos := fuj_des_campo('DES_CUENTA',NULL) ||
                    fuj_des_campo('COD_MONEDA',NULL) ||
                    fuj_des_campo('CAPITAL',NULL)    ||
                    fuj_des_campo('MORATORIO',NULL)  ||
                    fuj_des_campo('PUNITORIO',NULL)  ||
                    fuj_des_campo('IMPUESTO',NULL)   ||
                    fuj_des_campo('CARGO_IVA',NULL)  ||
                    fuj_des_campo('EFECTIVO',NULL)   ||
                    fuj_des_campo('CHQ_NBCO',NULL)     ||
                    fuj_des_campo('CRE_CUENTA',NULL) ||
                    fuj_des_campo('CRE_CTA_CON',NULL)||
                    fuj_des_campo('COD_BANCO',NULL)  ||
                    fuj_des_campo('NRO_CHEQUE',NULL) ||
                    fuj_des_campo('IMP_CHEQUE',NULL) ||
                    fuj_des_campo('TOT_A_COBRAR',NULL)||
                    fuj_des_campo('GASTOS',NULL);
    -- obtengo datos de la cuenta  --
    begin
      pav_ove.PR_OBT_DAT_OPE_VENCIDA(p_nro_cuenta,r_opeven);
    exception
     when others then
       v_cod_respuesta := '002';
       v_msj_respuesta := 'ERROR: Al buscar la cuenta '||sqlerrm;
    end;
    if v_cod_respuesta = '000' then
      -- Obtengo los datos de la caja --
      prj_obt_datos_caja(p_nro_caja,
                       r_opeven.cod_moneda,
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
        v_msj_respuesta := 'Realice la Apertura de Caja previamente';
      elsif v_fec_caja <> v_fec_actual then
        v_cod_respuesta := '005'; -- error
        v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      end if;
    end if;
    if v_cod_respuesta = '000' then
      -- AQUI LA VALIDACION DE SI ES PARA RETOMAR EN CAJA, SINO SIGUE ABAJO
      prj_ver_pen_caja(p_nro_cuenta,
                       v_cod_transaccion,
                       v_fec_actual,
                       v_cod_usuario,
                       v_hora,
                       v_cod_tran_pend,
                       v_cod_respuesta,
                       v_msj_respuesta);
      if v_cod_respuesta = '001' then  ---- debe retomar hay pendientes 'J'
        PRJ_OBT_PEND_VENCIDAS(p_nro_cuenta,
            v_fec_actual,
            v_hora,
            v_capital,
            v_moratorio,
            v_impuesto,
            v_cargos,
            v_iva,
            v_punitorio,
            v_tot_cre_cta,
            v_tot_cre_cta_con,
            v_cod_respuesta,
            v_msj_respuesta);

        if to_number(v_cod_respuesta) = 0 then
          v_cod_respuesta :='000';
        end if;
        --recuperar datos del movimiento
        for reg in movimientos loop
           v_mov_existente := v_mov_existente + 1;
           If reg.cod_transaccion = 740 then --efectivo
             v_monto_efectivo := reg.monto;
           elsif reg.cod_transaccion in (607, 610, 632) then --retencion 1,2,3
             v_monto_cheque   := reg.monto;
             if reg.cod_transaccion = 607 then
               v_tip_retencion := 1;
             elsif reg.cod_transaccion = 610 then
               v_tip_retencion := 2;
             elsif reg.cod_transaccion = 632 then
               v_tip_retencion := 3;
             end if;
           elsif reg.cod_transaccion = 606 then
             v_monto_cheque_n   := reg.monto;
           end if;
        end loop;
        --si no recuperó nada dar error
        if v_mov_existente <= 0 then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'No encuentra movimiento a retomar o está en otra oficina';
        end if;
      else ---  transaccion 139 normal,directo en caja
        --obtener los datos de la cuenta
        v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                 r_opeven.cod_modulo,
                                                 v_cod_transaccion,
                                                 r_opeven.estado,
                                                'C'); -- 'C'== CREDITO

        if v_msj_respuesta is not null then
          v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
        end if;

        pav_ove.PR_OBT_DEU_OPE_VENCIDA (p_nro_cuenta,
                                   v_fec_actual,
                                   v_mto_cobrado,
                                   v_error,
                                   v_msj_respuesta,
                                   v_capital,
                                   v_moratorio,
                                   v_punitorio,
                                   v_impuesto,
                                   v_cargos,
                                   v_car_iva,
                                   v_dia_mora,
                                   139);
        if v_error is null then
          v_cod_respuesta :='000';
        else
          v_cod_respuesta :='020';
        end if;

        /*v_capital   := r_opeven.sal_total;
        v_moratorio := r_opeven.sal_int_moratorio;
        v_punitorio := r_opeven.sal_int_punitorio;
        v_impuesto  := r_opeven.sal_impuesto;*/
        ---v_cargos    := p_gastos;
      end if;
    end if; -- fin de transaccion normal o pendiente
    ---- A PARTIR DE AQUI ES IGUAL PARA LA SALIDA DE AMBOS CASOS ---
    if v_cod_respuesta = '000' then
      if v_hora is null then  --- transaccion 139 normal
        v_tot_a_cobrar:= nvl(v_capital,0) + nvl(v_moratorio,0) +
                  nvl(v_punitorio,0) + nvl(v_impuesto,0) +
                  nvl(v_cargos,0) + nvl(v_iva,0) ;
        v_det_campos := fuj_des_campo('DES_CUENTA',r_opeven.denominacion) ||
                         fuj_des_campo('COD_MONEDA',r_opeven.cod_moneda) ||
                         fuj_des_campo('CAPITAL',v_capital)          ||
                         fuj_des_campo('MORATORIO',v_moratorio)      ||
                         fuj_des_campo('PUNITORIO',v_punitorio)      ||
                         fuj_des_campo('IMPUESTO',v_impuesto)        ||
                         fuj_des_campo('CARGO_IVA',nvl(v_cargos,0)+nvl(v_iva,0))||
                         fuj_des_campo('TOT_A_COBRAR',v_tot_a_cobrar)||
                         fuj_des_campo('GASTOS',nvl(v_cargos,0)+nvl(v_iva,0),null,'I')    ||
                         fuj_des_campo('EFECTIVO',v_monto_efectivo,null,'I')    ||
                         fuj_des_campo('CHQ_NBCO',v_monto_cheque_n,null,'I')    ||
                         fuj_des_campo('CRE_CUENTA',v_tot_cre_cta)   || --de los mov
                         fuj_des_campo('CRE_CTA_CON',v_tot_cre_cta_con);
      else
        --solo despliegue
        v_tot_a_cobrar:= nvl(v_capital,0) + nvl(v_moratorio,0) +
                  nvl(v_punitorio,0) + nvl(v_impuesto,0) +
                  nvl(v_cargos,0) ;
        v_det_campos := fuj_des_campo('DES_CUENTA',r_opeven.denominacion) ||
                         fuj_des_campo('COD_MONEDA',r_opeven.cod_moneda) ||
                         fuj_des_campo('CAPITAL',v_capital)          ||
                         fuj_des_campo('MORATORIO',v_moratorio)      ||
                         fuj_des_campo('PUNITORIO',v_punitorio)      ||
                         fuj_des_campo('IMPUESTO',v_impuesto)        ||
                         fuj_des_campo('CARGO_IVA',nvl(v_cargos,0)/*+nvl(v_iva,0)*/)||
                         fuj_des_campo('TOT_A_COBRAR',v_tot_a_cobrar)||
                         fuj_des_campo('GASTOS',nvl(v_cargos,0)+nvl(v_iva,0), null, 'D') ||
                         fuj_des_campo('EFECTIVO', ltrim(to_char(v_monto_efectivo)), null, 'D') ||
                         fuj_des_campo('CHQ_NBCO', ltrim(to_char(v_monto_cheque_n)), null, 'D') ||
                         fuj_des_campo('CRE_CUENTA',v_tot_cre_cta)   || --de los mov
                         fuj_des_campo('CRE_CTA_CON',v_tot_cre_cta_con);
      End if;
    end if;  -- sino hubo error para salida final
  end if;     -- fin  cuenta
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
 return(v_msj_salida);
end;
/

