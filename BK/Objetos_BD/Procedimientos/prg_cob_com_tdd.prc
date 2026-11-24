CREATE OR REPLACE PROCEDURE IT.PRG_COB_COM_TDD (p_nro_cuenta in varchar2,
                                             p_cod_modulo in number ,
                                             p_cod_modalidad in number,
                                             p_cod_moneda in varchar2,
                                             p_cod_persona in varchar2,
                                             p_cod_oficina in number,
                                             p_fec_recepcion in date,
                                             p_nro_secuencia in out number,
                                             p_cod_ofi_origen in number) is
--Proceso de Cobro de Comisiones por Renovación Masiva de TDD por --20/07/2020--DD
v_es_nocturno    varchar2(1);
v_hora            ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
v_fec_actual      date := pag_cal.fu_obt_fec_actual(3);
v_cod_usuario     ba_usuarios.cod_usuario%TYPE := user;
v_nvo_estado      ge_cuentas.estado%type;
v_procesar        varchar2(1) := 'S';
v_sal_disponible  ge_cuentas.sal_contable%type;
v_nro_documento   ge_movimientos.nro_documento%type;
v_nro_secuencia   ge_movimientos.nro_secuencia%type := p_nro_secuencia;
v_mto_cargo       ge_movimientos.monto%type;
v_mto_comision    ge_movimientos.monto%type;
v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
v_val_tas_impuesto ge_movimientos.val_tasa%type;
v_mto_impuesto     ge_movimientos.monto%type;
r_gmovi            ge_movimientos%rowtype;
v_cod_transaccion  ge_movimientos.cod_tra_padre%type := 569;
v_cod_tasa        ge_tasas.cod_tasa%type;
v_val_cargo       ge_tas_fechas.val_tasa%type;
v_fec_vigencia    ge_tas_fechas.fec_vigencia%type;
v_tip_valor       ge_tasas.tip_valor%type;
v_tipo            ge_tasas.tipo%type;
v_cod_error       number;
v_msj_error       varchar2(1000);
v_fecha           date:= null;

 BEGIN
   Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
   dbms_output.put_line(p_nro_cuenta);
   pae_cnf.G_COD_MODULO := p_cod_modulo;
   pag_gen.pr_obt_val_tasa(p_cod_modulo,
                           p_cod_modalidad,
                           p_cod_ofi_origen,
                           p_nro_cuenta,
                           p_cod_moneda,
                           0,
                           'N',
                           v_cod_tasa, --in out
                           v_cod_transaccion,
                           v_fecha,
                           v_val_cargo, --out
                           v_fec_vigencia, --out
                           v_tip_valor, --out
                           v_tipo, --out
                           p_cod_persona);

    v_mto_cargo        := null;
    v_cod_tra_impuesto := null;
    v_cod_tas_impuesto := null;
    v_mto_impuesto     := null;
    v_val_tas_impuesto := null;
    --Calcular el impuesto--
     prg_obt_car_impuesto(p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda, p_cod_modulo, p_cod_modalidad,
                          v_cod_transaccion, v_mto_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
                          v_mto_impuesto := nvl(v_mto_impuesto,0);
     if v_mto_impuesto = 0 then
        v_mto_cargo := v_val_cargo;
        v_mto_impuesto := round((round(v_mto_cargo*v_val_tas_impuesto))/100);
        v_mto_comision := nvl(v_mto_impuesto,0) + nvl(v_mto_cargo,0);
     end if;

    pag_cta.pr_ver_operacion(p_nro_cuenta,
                             569,
                             p_cod_modulo,
                             p_cod_modalidad,
                             'D',
                             p_cod_moneda,
                             v_mto_comision,
                             p_cod_ofi_origen,
                             -- out
                             pag_cta.g_ctas.cod_modulo,
                             pag_cta.g_ctas.cod_modalidad,
                             v_nvo_estado,
                             v_sal_disponible,
                             v_procesar,
                             503);
      v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,v_cod_usuario,v_es_nocturno);
      v_cod_error := pag_cta.g_cod_error;
      v_msj_error := pag_cta.G_MSJ_ERROR;

      if  v_cod_error = 0 or v_procesar = 'S' then
        if v_nro_secuencia > 990 then
           v_nro_secuencia := 1;
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,v_cod_usuario,v_es_nocturno);
        end if;
          if v_mto_comision > 0 then 
            --Actualizar el Saldo cta débito--
             v_nro_documento := s_nro_cob_cargo.nextval;
            pag_cta.pr_act_operacion(p_nro_cuenta,
                                     v_hora,
                                     'D',
                                     pag_cta.g_ctas.cod_moneda,
                                     v_mto_comision,
                                     v_cod_transaccion,
                                     503,
                                     v_nro_documento,
                                     null,
                                     p_cod_ofi_origen, --fug_obt_ofi_usuario(v_cod_usuario)--cod_ofi_origen
                                     p_cod_modulo,     --cod_mod_padre
                                     p_cod_modalidad,  --cod_mad_padre
                                     null,             --cod_tasa
                                     null,             --val_tasa
                                     substr('DÉBITO POR COBRO DE COMISION RENOV. TDD',1,99) ,
                                     'S',              --emi_aviso
                                     v_nro_secuencia,
                                     v_fec_actual);
           end if;
           if v_mto_cargo > 0 then 
              --Insertar el Movimiento Por el Cargo
               r_gmovi.cod_usuario     := substr(v_cod_usuario,1,10);
               r_gmovi.hora            := v_hora;
               r_gmovi.fecha           := v_fec_actual;
              -- Aumento la secuencia
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.cod_modulo      := p_cod_modulo;
               r_gmovi.cod_modalidad   := p_cod_modalidad;
               r_gmovi.cod_oficina     := p_cod_oficina;
               r_gmovi.nro_cuenta      := null;  --p_nro_cuenta
               r_gmovi.cod_moneda      := p_cod_moneda;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_transaccion;
               r_gmovi.cod_mod_padre   := p_cod_modulo;
               r_gmovi.cod_mad_padre   := p_cod_modalidad;
               r_gmovi.cod_transaccion := v_cod_transaccion;
               r_gmovi.monto           := v_mto_cargo;
               r_gmovi.nro_documento   := v_nro_documento;
               r_gmovi.nro_documento2  := null;
               r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'CARGO POR COMISION RENOV. TDD';
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := null;
               r_gmovi.cod_tasa        := v_cod_tasa;
               r_gmovi.val_tasa        := v_val_cargo;
               r_gmovi.tip_mov_rubro   := null;
               r_gmovi.referencia      := p_nro_cuenta;
               r_gmovi.cod_persona     := p_cod_persona;
            end if;
            if v_mto_impuesto > 0 then 
               pag_gen.pr_ins_ge_movimiento(r_gmovi);
               --Insertar el Movimiento Por el Impuesto--
               r_gmovi.cod_usuario     := substr(v_cod_usuario,1,10);
               r_gmovi.hora            := v_hora;
               r_gmovi.fecha           := v_fec_actual;
               -- Aumento la secuencia
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.cod_modulo      := p_cod_modulo;
               r_gmovi.cod_modalidad   := p_cod_modalidad;
               r_gmovi.cod_oficina     := p_cod_oficina;
               r_gmovi.nro_cuenta      := null;  --p_nro_cuenta
               r_gmovi.cod_moneda      := p_cod_moneda;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_transaccion;
               r_gmovi.cod_mod_padre   := p_cod_modulo;
               r_gmovi.cod_mad_padre   := p_cod_modalidad;
               r_gmovi.cod_transaccion := v_cod_tra_impuesto; --518
               r_gmovi.monto           := v_mto_impuesto;
               r_gmovi.nro_documento   := v_nro_documento;
               r_gmovi.nro_documento2  := null;
               r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'IVA POR COMISION RENOV. TDD';
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := null;
               r_gmovi.cod_tasa        := v_cod_tas_impuesto;
               r_gmovi.val_tasa        := v_val_tas_impuesto;
               r_gmovi.tip_mov_rubro   := null;
               r_gmovi.referencia      := p_nro_cuenta;
               r_gmovi.cod_persona     := p_cod_persona;

               pag_gen.pr_ins_ge_movimiento(r_gmovi);
               p_nro_secuencia := v_nro_secuencia;
            end if; 

      elsif v_procesar = 'N' and pag_cta.fu_obt_cod_error() in (25,29,31) then  -- sino puede procesar y si es problema de saldo
             --Insertar en Movimientos Pendientes
             insert into ge_mov_pendientes
               (nro_cuenta,fecha,cod_modulo,cod_modalidad,cod_transaccion,cod_mod_padre,cod_mad_padre,cod_tra_padre,monto,saldo,hora,cod_usuario,
                cod_moneda,cod_oficina,estado,cod_ofi_origen,concepto,cod_tasa,val_tasa,nro_documento,observacion,car_manual,
                cod_persona,referencia,fec_vencimiento)
             values
               (p_nro_cuenta,v_fec_actual,p_cod_modulo,p_cod_modalidad,v_cod_transaccion,
                p_cod_modulo,p_cod_modalidad,v_cod_transaccion,v_mto_comision,v_mto_comision,v_hora,substr(v_cod_usuario,1,10),
                p_cod_moneda,p_cod_ofi_origen,'I',p_cod_ofi_origen,
                'COBRO DE COMISION RENOV. TDD',163,v_mto_cargo,v_nro_documento,v_msj_error,'N',
                p_cod_persona,p_nro_cuenta,null);
       end if;     
       
       

      if v_cod_error not in (0,25,29,31) then
        insert into ge_log_errores(cod_programa, campo1, dato1, campo2, dato2, det_error)
        values ('PRG_COB_COM_TDD','Cuenta:',p_nro_cuenta,'Monto:',v_mto_comision, v_msj_error);
      end if;
 END;
/

