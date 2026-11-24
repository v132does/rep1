CREATE OR REPLACE PROCEDURE IT.PRB_APU_MASIVOS
IS
-- Simgia - Juan Bauer
-- Modificado por Gilson Caballero , Alejandro Ferreira, Nicolas Andrusky
-- variables para control

v_no_coincide_moneda   NUMBER(16);
g_ok_procesar          varchar2(01);
g_cod_error            varchar2(03);
v_no_tiene_rubro       number(04);
v_cantidad             number(01);
v_usu_rol              varchar2(15);
v_usu_rol_permiso      varchar2(15);

v_nro_referencia    NUMBER(15);
r_gmovi ge_movimientos%rowtype;
v_hora varchar2(8);
v_fec_actual date;
v_nro_secuencia number(3);

v_cod_ofi_operacion number(03);
v_cod_ofi_destino number(03);
v_cod_rubro varchar2(15);
v_cod_rubro_C cb_rubros.cod_rubro%type;
v_cod_rubro_D cb_rubros.cod_rubro%type;
v_descripcion varchar2(100);
v_nro_cuenta varchar2(15);
v_tip_mov_rubro varchar2(1);
v_cotizacion number(14,8);
v_monto number(18,2);
v_cod_moneda varchar2(3);
v_cod_transaccion number(4);
v_cod_transaccion_existe number(4);
v_tipo_transaccion ge_transacciones.tipo%type;
v_ult_ofi_origen cb_apu_masivos_tmp.cod_ofi_operacion%type :=0 ;
v_mto_debito_equi_gs number;
v_mto_credito_equi_gs number;
v_cotizacion_actual number;
v_ult_nro_referencia cb_apu_masivos_tmp.nro_referencia%type := 0;
v_cod_mon_local ba_monedas.cod_moneda%type;
v_mto_mon_local ge_movimientos.mto_equ_local%type;
v_redondeo number(10);
--v_cb_rubro varchar2(15);
v_mov_rubro number(10);
v_can_lineas number(10);
-- Fecha: 27/06/2016.
-- Requerimiento: CNFDEEVO-46.
v_existe     number(10) := 0;
v_referencia cb_apu_masivos_tmp.referencia%type;
v_cod_area   cb_apu_masivos_tmp.cod_area%type;

CURSOR APUNTES IS
 -- Fecha: 27/06/2016.
 -- Requerimiento: CNFDEEVO-46.
 select tam.cod_ofi_operacion,
        tam.cod_ofi_destino,
        tam.cod_rubro,
        tam.descripcion,
        tam.nro_cuenta,
        tam.tip_mov_rubro,
        tam.cotizacion,
        tam.monto,
        tam.cod_moneda,
        tam.nro_referencia,
        tam.cod_transaccion,
        tam.referencia,
        tam.cod_area
 from cb_apu_masivos_tmp tam
 where tam.cod_usuario = user
 order by tam.cod_ofi_operacion, tam.nro_referencia;


CURSOR boletean is
select distinct nvl(nro_referencia,-1) nro_referencia
  from cb_apu_masivos_tmp t
 where SUBSTR(t.COD_RUBRO,1,1) IN ('1','2')
   and t.cod_rubro is not null
   and t.cod_moneda <> v_cod_mon_local
   and t.cod_usuario = user
   and exists(select 1 from cb_apu_masivos_tmp p
               where nvl(p.nro_referencia,-1)=nvl(t.nro_referencia,-1)
                 and p.cod_rubro is not null
                 and t.cod_rubro <> p.cod_rubro
                 and p.cod_usuario = user
                 and (
                         (SUBSTR(p.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(p.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(p.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(p.COD_RUBRO,1,1) IN ('1','2')
                          )
                        ))
union all
select distinct nvl(nro_referencia,-1)
  from cb_apu_masivos_tmp t, cc_cta_bancarias b
 where t.nro_cuenta=b.nro_cuenta
   and b.cod_moneda <> v_cod_mon_local
   and SUBSTR(b.COD_RUBRO,1,1) IN ('1','2')
   and t.cod_usuario = user
   and exists(select 1 from cb_apu_masivos_tmp p
               where nvl(p.nro_referencia,-1)=nvl(t.nro_referencia,-1)
                 and p.cod_rubro is not null
                 and b.cod_rubro <> p.cod_rubro
                 and p.cod_usuario = user
                 and (
                         (SUBSTR(p.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(p.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(p.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(p.COD_RUBRO,1,1) IN ('1','2')
                          )
                        ))
order by 1;


 --Cursor de Debito
  CURSOR rubro_deb (p_cod_ofi_operacion in cb_apu_masivos_tmp.cod_ofi_operacion%type,
                   p_nro_referencia    in cb_apu_masivos_tmp.nro_referencia%type) is

     select  a.cod_rubro, a.nro_referencia
        from cb_apu_masivos_tmp a
        where a.tip_mov_rubro = 'D'
        and a.cod_ofi_operacion=p_cod_ofi_operacion
        and a.nro_referencia=p_nro_referencia
        and a.cod_usuario=user;
  --Cursor de Credito
  CURSOR rubro_cred (p_cod_ofi_operacion in cb_apu_masivos_tmp.cod_ofi_operacion%type,
                   p_nro_referencia    in cb_apu_masivos_tmp.nro_referencia%type) is

     select  a.cod_rubro, a.nro_referencia
        from cb_apu_masivos_tmp a
        where a.tip_mov_rubro = 'C'
        and a.cod_ofi_operacion=p_cod_ofi_operacion
        and a.nro_referencia=p_nro_referencia
        and a.cod_usuario=user;

  --procedimiento para el rubro
  PROCEDURE LP_VAL_RUBROS(p_cod_ofi_operacion in cb_apu_masivos_tmp.cod_ofi_operacion%type,
                         p_nro_referencia    in cb_apu_masivos_tmp.nro_referencia%type)  IS

  Begin
  --Se valida los rubros no seas de Orden vs Patrimoniales
     for deb in rubro_deb(p_cod_ofi_operacion, p_nro_referencia)  loop
            v_cod_rubro_D := substr(deb.cod_rubro, 1, 1);
            if v_cod_rubro_D = 4 or v_cod_rubro_D = 5 then
              for cred in rubro_cred(p_cod_ofi_operacion, p_nro_referencia)  loop
                  v_cod_rubro_C := substr(cred.cod_rubro, 1, 1);
                  if v_cod_rubro_D <> v_cod_rubro_C then
                    raise_application_error(-20000,'ERROR: No se puede procesar. Las cuentas de orden no pueden combinarse. En referencia ' || deb.nro_referencia ||  ' Favor verificar ' );
                 end if;

                  if v_cod_rubro_D <> v_cod_rubro_C then
                    raise_application_error(-20000,'ERROR: No se puede procesar. Las cuentas de contingentes no pueden combinarse. En referencia ' || deb.nro_referencia ||  ' Favor verificar ' );
                 end if;
              end loop;
            end if;
      end loop;
     End;


BEGIN

    --inicializar secuencia
    v_nro_secuencia := 0;
    v_hora := to_char(sysdate, 'hh24:mm:ss');
    v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    PAE_CNF.G_COD_MODULO := 1;

    --verificar que cuadren los montos por oficina
    for reg in apuntes loop
     -- Monto no puede ser nulo
     IF reg.monto is null then
        raise_application_error(-20000,'Monto no puede ser nulo '||reg.cod_rubro||' '||reg.nro_cuenta);
     END IF;
     --Verifica que traiga cotizacion si la moneda no es local
     if reg.cod_moneda <> v_cod_mon_local and (reg.cotizacion is null or reg.cotizacion =0) then
       raise_application_error(-20000,'Debe Ingresar la cotizacion a la moneda'||reg.cod_moneda);
     end if;
     ----Verifica que el rubro este cargado---
     if reg.cod_rubro is null and reg.nro_cuenta is null then
        raise_application_error(-20000,'No se puede procesar la transacción, rubro no valido'||reg.cod_rubro);
     end if;

     ----Valida que oficinas no esten nulos---
     if reg.cod_ofi_operacion is null or reg.cod_ofi_destino is null then
        raise_application_error(-20000,'Codigo de Oficina Destino y/u Operacion no debe ser nula. En el rubro: '||reg.cod_rubro);
     end if;
     ----Valida que Numero de Referencia O Transaccion este cargada-----
      if reg.nro_referencia is null or reg.cod_transaccion is null then
        raise_application_error(-20000,'Numero de Referencia y/o Codigo de Transaccion no puede ser nula. En el rubro: '||reg.cod_rubro);
     end if;
     ----Verifica que Descripcion este cargada----
      if reg.descripcion is null then
        raise_application_error(-20000,'Descripcion no puede estar vacia. En el rubro: '||reg.cod_rubro || ' ref. ' || reg.nro_referencia|| ' trn. ' || reg.cod_transaccion|| ' monto ' || reg.monto);
     end if;
     begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
     ----Toma cotizacion actual si usuario no pertenece a ROL: Contabilidad o Contador-----
     begin
     v_usu_rol :=user;
       select count(*)
       into v_cantidad
       from ba_usu_roles usu
       where usu.cod_usuario=user
       and usu.cod_rol in('CONTADOR','CONTABILIDAD');
       exception
          when others then
        v_cantidad := 0;
      end;

       if reg.cod_moneda <> v_cod_mon_local and v_cantidad = 0 then
          v_cotizacion_actual := fug_obt_cotizacion(reg.cod_moneda,v_fec_actual);
        if reg.cotizacion <> v_cotizacion_actual then
             raise_application_error(-20000,'No se puede procesar, cotizacion no coinciden. Favor verificar '||reg.cotizacion);
        end if;
       end if;
      ----Verifica si el usuario puede utilizar el rubro según el rol asignado
      if reg.cod_rubro is not null then
         v_usu_rol_permiso := fub_ver_rub_rol(reg.cod_rubro,v_usu_rol,v_fec_actual);
         if  v_usu_rol_permiso = 'N' then
            raise_application_error(-20000,'No se puede procesar, usuario '|| v_usu_rol|| ' no esta autorizado para interactuar con el rubro: ' ||reg.cod_rubro);
         end if;
      end if;
      --verificar que coincidan monedas con rubro
     begin
        select  a.cod_rubro
        into v_no_coincide_moneda
        from cb_apu_masivos_tmp a, cb_rubros b
        where a.cod_rubro = b.cod_rubro
        and a.cod_moneda <> b.cod_moneda
        and a.cod_usuario = user
        group by a.cod_rubro;
        exception
              when too_many_rows then
              v_no_coincide_moneda := 1;
              when NO_DATA_FOUND then
              null;
     end;

     --
     IF v_no_coincide_moneda > 0 THEN
        raise_application_error(-20000,'No se puede procesar la transacción, la moneda no coinciden con el rubro'||v_cod_rubro);
     end if;
     v_tipo_transaccion := reg.tip_mov_rubro;
      v_cod_transaccion := reg.cod_transaccion;
      -----------------------------------------------------------------------------------
     /* --Verifica que el codigo de transaccion pertenesca a Debito o Credito
      v_tipo_transaccion := reg.tip_mov_rubro;
      v_cod_transaccion := reg.cod_transaccion;
 begin
        select  ge.cod_transaccion,ge.tipo
        into v_cod_transaccion_existe, v_tipo_transaccion
        from ge_transacciones ge
        where ge.cod_transaccion = reg.cod_transaccion
        and ge.tipo = reg.tip_mov_rubro
        and reg.nro_cuenta is not null;
       exception
         when too_many_rows then
              v_cod_transaccion_existe := 1;
         when NO_DATA_FOUND then
              null;
    end;

     --
     IF v_cod_transaccion_existe > 0 THEN
        raise_application_error(-20000,'No se puede procesar la transacción, el codigo de transaccion no corresponde al tipo de movimiento Debito o Credito. Favor verifique en codigo de transaccion: '||reg.cod_transaccion);
     end if;
     */
     --Verifica que codigo moneda este cargada----
     if reg.cod_moneda is null then
        raise_application_error(-20000,'Codigo de Moneda no debe ser nula. En el rubro: '||reg.cod_rubro);
     end if;
     --Verifica que la cotizacion cuando el registro es en Gs venga vacio o null
     if reg.cod_moneda = v_cod_mon_local and (reg.cotizacion is not null or reg.cotizacion<>'') then
       raise_application_error(-20000,'Para '||v_cod_mon_local||' la cotizacion debe cargarse vacia.');
     end if;
      --Verifica que solo ingrese D o C en el campo tip_mov_rubro
     if (reg.tip_mov_rubro = 'C' or reg.tip_mov_rubro = 'D') then
        null;
     else
       raise_application_error(-20000,'Debe Ingresar C para Credito, D para Debito');
     end if;
      -- Validar que cuadren los Débitos y créditos
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);
      --v_mto_mon_local := round(v_monto * v_cotizacion,v_redondeo);

     select sum(round(a.monto * decode(a.cod_moneda,'GS',1, decode(nvl(a.cotizacion,1),1,1,0,1,nvl(a.cotizacion,1))),v_redondeo)) monto
       into v_mto_debito_equi_gs
       from cb_apu_masivos_tmp a
      where a.tip_mov_rubro = 'D'
        and a.cod_ofi_operacion=reg.cod_ofi_operacion
        and a.nro_referencia=reg.nro_referencia
        and a.cod_usuario = user;
      --
      select sum(round(a.monto* decode(a.cod_moneda,'GS',1, decode(nvl(a.cotizacion,1),1,1,0,1,nvl(a.cotizacion,1))), v_redondeo)) monto
       into v_mto_credito_equi_gs
       from cb_apu_masivos_tmp a
      where a.tip_mov_rubro = 'C'
        and a.cod_ofi_operacion=reg.cod_ofi_operacion
        and a.nro_referencia=reg.nro_referencia
        and a.cod_usuario = user;

    --Se llama al procedimiento para ir a validar los rubros
         LP_VAL_RUBROS(reg.cod_ofi_operacion, reg.nro_referencia);

        ---
      if v_mto_credito_equi_gs is null or v_mto_debito_equi_gs is null then
           raise_application_error(-20000,'No se puede procesar la transacción, Debito o Credito esta nulo '||reg.cod_ofi_operacion||
          ' Ref. '||reg.nro_referencia);
      end if;

      if v_mto_credito_equi_gs <> v_mto_debito_equi_gs and ABS(v_mto_credito_equi_gs - v_mto_debito_equi_gs)>1 then
          raise_application_error(-20000,'No se puede procesar la transacción, los montos debito y credito no cuadran en la oficina '||reg.cod_ofi_operacion||
          ' Ref. '||reg.nro_referencia);
      end if;
      --- Verificar si el rubro existe
      if reg.cod_rubro is not null then
         begin
           select 1 into v_no_tiene_rubro
             from cb_rubros
            where cod_rubro = reg.cod_rubro
            and imputable = 'S';
           exception
              when no_data_found then
                 raise_application_error(-20000,'No se puede procesar la transacción, el rubro no existe o no es imputable: '||reg.cod_rubro);
              when others then null;
         end;
      end if;
      
      -- Validación para el Inventario de Cuentas de Resultado.
      -- Requerimiento: CNFDEEVO-46.
      IF reg.referencia IS NULL AND substr(reg.cod_rubro,1,1) IN ('6','7') THEN
         raise_application_error(-20000,'Debe ingresar un Número de Cuenta en el campo REFERENCIA cuando afecta un Rubro Contable de Resultado, ref. ' || reg.nro_referencia || ' descripción: ' || reg.descripcion);
      ELSIF reg.referencia IS NOT NULL AND substr(reg.cod_rubro,1,1) IN ('6','7') THEN
         BEGIN
            SELECT 1
              INTO v_existe
              FROM ge_cuentas gc
             WHERE gc.nro_cuenta = reg.referencia;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,'El Número de Cuenta registrado en el campo REFERENCIA no existe, ref. ' || reg.nro_referencia || ' descripción: ' || reg.descripcion);
         END;
      ELSIF reg.referencia IS NOT NULL AND substr(reg.cod_rubro,1,1) NOT IN ('6','7') THEN
          raise_application_error(-20000,'El campo REFERENCIA debe estar vacío para los rubros contable que no son Cuentas de Resultados, ref. ' || reg.nro_referencia || ' descripción: ' || reg.descripcion);
      END IF;
      -- Verifica el Código de Centro de Costos.
      IF reg.cod_area IS NULL AND substr(reg.cod_rubro,1,1) = '7' THEN
         raise_application_error(-20000,'Debe ingresar el código de centro de costo, ref. ' || reg.nro_referencia || ' descripción: ' || reg.descripcion);
      ELSIF reg.cod_area IS NOT NULL AND substr(reg.cod_rubro,1,1) = '7' THEN
         BEGIN
            SELECT 1
              INTO v_existe
              FROM ba_areas ba
             WHERE ba.cod_area = reg.cod_area
               AND ba.cod_oficina = reg.cod_ofi_destino;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,'El Código de Centro de Costo no existe para la oficina: '||reg.cod_ofi_destino || ' en ref. ' || reg.nro_referencia || ' descripción: ' || reg.descripcion);
         END;
      ELSIF reg.cod_area IS NOT NULL AND substr(reg.cod_rubro,1,1) <> '7' THEN
         raise_application_error(-20000,'El campo código de área debe estar vacío para los rubros contables que no son Cuentas de Resultados(Pérdida), ref. ' || reg.nro_referencia || ' descripción: ' || reg.descripcion);
      END IF;
      --
    end loop;
    --- Verificar que estén correctamente cargadas las lineas para boleteo
    FOR reg in boletean LOOP
       --- Solo pueden ingresarse dos lineas cuando la operación va a boletear
       select count(*)
         into v_can_lineas
         from cb_apu_masivos_tmp p
        where p.nro_referencia = reg.nro_referencia
        and p.cod_usuario = user;
       if v_can_lineas > 2 then
          raise_application_error(-20000,
          'Movimiento con boleteo no puede tener más de dos líneas, verifique ref: '||reg.nro_referencia);
       end if;
    END LOOP;
    --- FIN DE LAS VALIDACIONES

    --- INICIO DE LAS OPERACIONES

     IF APUNTES%ISOPEN THEN
        CLOSE APUNTES;
     END IF;
     --se recorre  el cursor para ingresar los movimientos
      OPEN APUNTES;
      LOOP
            -- Fecha: 27/06/2016.
            -- Requerimiento: CNFDEEVO-46.
            FETCH APUNTES INTO v_cod_ofi_operacion,
                                v_cod_ofi_destino,
                                v_cod_rubro,
                                v_descripcion,
                                v_nro_cuenta,
                                v_tip_mov_rubro,
                                v_cotizacion,
                                v_monto,
                                v_cod_moneda,
                                v_nro_referencia,
                                v_cod_transaccion,
                                v_referencia,
                                v_cod_area;
            EXIT WHEN APUNTES%NOTFOUND;
      begin
          --
          if v_ult_nro_referencia <> v_nro_referencia then
             --se incrementa en 60 minutos la hora actual
              --v_hora:= to_char(to_number(substr(v_hora,1,2)+1))||substr(v_hora,3);
              v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
              v_nro_secuencia := 0;
              v_ult_nro_referencia := v_nro_referencia;
          end if;
          --
          if v_ult_ofi_origen <> v_cod_ofi_operacion then
             v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
             v_nro_secuencia := 0;
             v_ult_ofi_origen := v_cod_ofi_operacion;
          end if;
          --
          if v_nro_secuencia > 998 then
             v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
             v_nro_secuencia := 0;
          end if;
          
          -- Fecha: 27/06/2016.
          -- Requerimiento: CNFDEEVO-46.
          r_gmovi.referencia     := null;
          r_gmovi.nro_documento2 := null;

          if v_cod_rubro is not null then
                --- Inicializar datos cabecera del movimiento
                r_gmovi.cod_usuario    := user;
                r_gmovi.hora           := v_hora;
                r_gmovi.fecha          := v_fec_actual;
                r_gmovi.fec_valor      := v_fec_actual;
                r_gmovi.cod_mod_padre  := 1;--SPI 3394
                r_gmovi.cod_mad_padre  := 1;--SPI 3394
                r_gmovi.cod_modulo     := 2;
                r_gmovi.cod_modalidad  := 21;
                r_gmovi.cod_oficina    := v_cod_ofi_destino;
                r_gmovi.cod_ofi_origen := v_cod_ofi_operacion;
                r_gmovi.cod_moneda     := v_cod_moneda;
                r_gmovi.estado         := 'N';
                r_gmovi.reversado      := 'N';
                r_gmovi.emi_aviso      := 'N';
                r_gmovi.protegido      := 'N';
                r_gmovi.COD_RUBRO     := v_cod_rubro;
                r_gmovi.tip_mov_rubro := v_tip_mov_rubro;
/*
                if v_nro_secuencia + 2 > 999 then
                   v_nro_secuencia := 0;
                   v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                   r_gmovi.hora    := v_hora;
                end if;*/
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_tra_padre   := 100;
                r_gmovi.cod_transaccion := v_cod_transaccion;
                r_gmovi.concepto        := substr('APU MASI '||v_descripcion,1,100);
                r_gmovi.monto           := v_monto;
                r_gmovi.nro_documento   := v_nro_referencia;
                r_gmovi.cotizacion      := v_cotizacion;
                v_mto_mon_local := null;
                if v_cotizacion is not null then
                   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);
                   v_mto_mon_local := round(v_monto * v_cotizacion,v_redondeo);
                end if;
                r_gmovi.mto_equ_local   := v_mto_mon_local;
                -- Fecha: 27/06/2016.
                -- Requerimiento: CNFDEEVO-46.
                r_gmovi.referencia     := v_referencia;
                r_gmovi.nro_documento2 := v_cod_area;
                --
                pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
           else
            if v_nro_cuenta is not null then
                pag_cta.PR_OBT_CUENTA(v_nro_cuenta);
     --- Validar el tipo de movimiento vs la transaccion
    begin
         select  ge.tipo
                 into v_tipo_transaccion
                 from ge_transacciones ge
                 where ge.cod_transaccion = v_cod_transaccion
                 and ge.cod_modalidad = pag_cta.g_ctas.cod_modalidad
                 and ge.cod_modulo = pag_cta.g_ctas.cod_modulo;
             if v_tipo_transaccion <> v_tip_mov_rubro then
                 raise_application_error(-20000,'No se puede procesar la transacción, el codigo de transaccion no corresponde al tipo de movimiento Debito o Credito. Favor verifique en codigo de transaccion: '||v_cod_transaccion);
             end if;
    end;

     --- Verificar que pueda realizarse la operación

                pag_cta.pr_ver_operacion (v_nro_cuenta,
                              100,
                              1,--SPI 3394
                              1,--SPI 3394
                              v_tip_mov_rubro,
                              v_cod_moneda,
                              v_monto,
                              v_cod_ofi_operacion,
                              pag_cta.g_ctas.cod_modulo,
                              pag_cta.g_ctas.cod_modalidad,
                              pag_cta.g_ctas.nvo_estado,
                              pag_cta.g_ctas.sal_disponible,
                              g_ok_procesar,
                              v_cod_transaccion);

              IF NVL(g_ok_procesar,'N') = 'S' THEN
                 --verifica el monto, si es cero da error
                 if g_cod_error = 00 then
                    if v_monto = 0 then
                       g_ok_procesar := 'N';
                       raise_application_error(-20000,'No puede procesar oper. con Monto Cero. Cta. '||(v_nro_cuenta));
                       g_cod_error := 89;
                    end if;
                 end if;
              else
                 g_ok_procesar := 'N';
                 raise_application_error(-20000,'Cta: '||v_nro_cuenta||' - '||pag_Cta.G_MSJ_ERROR);
              end if;


           pag_cta.PR_ACT_OPERACION(v_nro_cuenta,
                                    v_hora,
                                    v_tip_mov_rubro,
                                    v_cod_moneda,
                                    v_monto,
                                    100,
                                    v_cod_transaccion,
                                    v_nro_referencia,
                                    v_cotizacion,
                                    v_cod_ofi_operacion,
                                    1,--SPI 3394
                                    1,--SPI 3394
                                    null,
                                    null,
                                    substr('APU MASI '||v_descripcion,1,100),
                                    'S',
                                    v_nro_secuencia,
                                    v_fec_actual);
            IF pag_cta.G_COD_ERROR <> 0 OR pag_cta.G_OK_PROCESAR='N' THEN
                raise_application_error(-20000,'Cta: '||v_nro_cuenta||' - '||pag_Cta.G_MSJ_ERROR);
            END IF;
            end if;
          end if;
      end;
      END LOOP;
      CLOSE APUNTES;

END;
/

