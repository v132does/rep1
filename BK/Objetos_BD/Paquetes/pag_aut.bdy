create or replace package body it.PAG_AUT is
/* Obtiene los datos de la autorizacion pendiente. */
PROCEDURE PR_OBT_AUTORIZACION
 (P_NRO_CUENTA IN GE_AUTORIZACIONES.NRO_CUENTA%TYPE
 ,P_COD_TRA_PADRE IN GE_AUTORIZACIONES.COD_TRA_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_AUTORIZACIONES.COD_TRANSACCION%TYPE
 ,P_IMPORTE IN GE_AUTORIZACIONES.VALOR%TYPE
 ,P_COD_USU_AUTORIZADOR IN OUT GE_AUTORIZACIONES.COD_USU_AUTORIZADOR%TYPE
 ,P_COD_AUTORIZACION IN OUT GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 )
 IS
 v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
BEGIN
   -- Busco los datos de la autorizacion
   Select COD_USU_UTILIZADOR, COD_AUTORIZACION
     into p_cod_usu_autorizador, p_cod_autorizacion
     from GE_AUTORIZACIONES
    where NRO_CUENTA = p_nro_cuenta
      and fecha = v_fec_actual
      and COD_TRANSACCION = p_cod_transaccion
      and COD_TRA_padre    = NVL(p_cod_tra_padre,COD_TRA_padre)
      and (VALOR >= p_importe or -- que autorice el monto o
           EXIMIDO = 'S')                 -- exima el valor
      and cod_usu_utilizador is null -- que no fue utilizado por nadie
      and rownum = 1;              -- el primero que exista
EXCEPTION
   when no_data_found then
      p_cod_usu_autorizador := null;
      p_cod_autorizacion    := null;
   when others then
      raise_application_error(-20001, 'Error en PR_OBT_AUTORIZACION '||sqlerrm);
END;
--- Obtener autorizacion pendiente
PROCEDURE PR_OBT_AUT_PENDIENTE
 (P_NRO_CUENTA IN GE_AUTORIZACIONES.NRO_CUENTA%TYPE
 ,P_COD_TRA_PADRE IN GE_AUTORIZACIONES.COD_TRA_PADRE%TYPE
 ,P_COD_MOD_PADRE IN GE_AUTORIZACIONES.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_AUTORIZACIONES.COD_MAD_PADRE%TYPE
 ,P_VALOR IN GE_AUTORIZACIONES.VALOR%TYPE
 ,P_COD_AUTORIZACION IN OUT GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_COD_USU_AUTORIZADOR IN OUT GE_AUTORIZACIONES.COD_USU_AUTORIZADOR%TYPE
 ) IS
 v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
BEGIN
   select cod_autorizacion
     into p_cod_autorizacion
     from ge_autorizaciones
    where nro_cuenta = p_nro_cuenta
      and fecha = v_fec_actual
      and cod_tra_padre = p_cod_tra_padre
      and cod_mod_padre = p_cod_mod_padre
      and (p_cod_mod_padre in (6,5) or cod_mad_padre = p_cod_mad_padre)
      and (valor = p_valor or eximido = 'S') -- Debe ser por el monto o eximido = S
      and cod_usu_utilizador is null
      and rownum = 1;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- raise_application_error(-20000,'No existe autorizacion pendiente p/ la Cta: '||
    -- p_nro_cuenta||' Tra.Padre: '||to_char(p_cod_mod_padre)||'-'||
    -- to_Char(p_cod_mad_padre)||'-'||to_char(p_cod_tra_padre)||
    --' Val: '||to_char(p_valor));
    p_cod_autorizacion := null;
    p_cod_usu_autorizador := null;
    return;

END;
--- Verificar si posee autorizaciones pendientes aun la cuenta
FUNCTION FU_OBT_PED_PENDIENTE
 (P_NRO_CUENTA IN GE_AUTORIZACIONES.NRO_CUENTA%TYPE)
RETURN BOOLEAN IS
   v_existe number(1);
BEGIN
   select 1 into v_existe
     from ge_aut_pedidos ped, ge_movimientos mov
    where ped.cod_usuario = mov.cod_usuario
      and ped.fecha = mov.fecha
      and ped.hora = mov.hora
      and mov.estado = 'X'
      and ped.estado = 'S'
      AND mov.reversado = 'N'
      and mov.nro_cuenta = p_nro_cuenta;
   return true;
EXCEPTION
   when no_data_found then
      return false;
   when too_many_rows then
      return true;
END;
--- Actualizar campos utilizacion de la autorizacion
PROCEDURE PR_UTI_AUTORIZACION
 (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_COD_USUARIO IN GE_AUTORIZACIONES.COD_USU_UTILIZADOR%TYPE
 ,P_FECHA IN GE_AUTORIZACIONES.FEC_UTILIZACION%TYPE
 ,P_HORA IN GE_AUTORIZACIONES.HOR_UTILIZACION%TYPE
 ) IS
v_nro_cuenta varchar2(20);
v_can_autorizaciones number;
v_cod_modalidad ge_cuentas.cod_modalidad%type;
v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
BEGIN
   update ge_autorizaciones
      set cod_usu_utilizador = p_cod_usuario,
          fec_utilizacion = p_fecha,
          hor_utilizacion = p_hora
    where cod_autorizacion = p_cod_autorizacion;
   if sql%notfound then
      raise_application_error(-20000,
      'Autorizacion '||p_cod_autorizacion||' no pudo actualizarse');
   else
      -- tomo la cuenta de la autorizacion para ver si hay otros pendientes
      begin
        select a.nro_cuenta, b.cod_modalidad
          into v_nro_cuenta, v_cod_modalidad
          from ge_cuentas b, ge_autorizaciones a
         where a.cod_autorizacion = p_cod_autorizacion
           and a.nro_cuenta = b.nro_cuenta;
        -- busco si ya no hay autorizaciones pendientes
        select count(*)
          into v_can_autorizaciones
          from ge_autorizaciones
         where nro_cuenta = v_nro_cuenta
           and fecha = v_fec_actual
           and cod_usu_utilizador is null
           and rownum = 1;
        if v_can_autorizaciones = 0 then
            if v_cod_modalidad = 31 then
               update ah_cta_vistas
                  set aut_pendiente = 'N'
                where nro_cuenta = v_nro_cuenta;
            elsif v_cod_modalidad in (32,37,38) then
               update ah_cta_plazos
                  set aut_pendiente = 'N'
                where nro_cuenta = v_nro_cuenta;
            elsif v_cod_modalidad in (33,34,35,36) then
               update ah_cta_certificados
                  set aut_pendiente = 'N'
                where nro_cuenta = v_nro_cuenta;
            elsif v_cod_modalidad in (41) then
               update cc_cta_corrientes
                  set aut_pendiente = 'N'
                where nro_cuenta = v_nro_cuenta;
            end if;
        end if;
      exception
         when no_data_found then
            raise_application_error(-20000,'Error al buscar Autorizacion '||p_cod_autorizacion);
         when others then
            --raise_application_error(-20000,'Error al buscar Autorizacion '||p_cod_autorizacion||'-'||sqlerrm);
            null;
      end;
   end if;
END;
--- Recuperar usuario que va a autorizar el pedido
FUNCTION FU_OBT_USU_AUTORIZADOR
 (P_COD_TRA_PADRE IN GE_AUTORIZADORES.COD_TRA_PADRE%TYPE
 ,P_COD_MOD_PADRE IN GE_AUTORIZADORES.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_AUTORIZADORES.COD_MAD_PADRE%TYPE
 ,P_COD_OFICINA IN GE_AUTORIZADORES.COD_OFICINA%TYPE
 ,P_MONTO IN GE_AUTORIZADORES.MONTO%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ) RETURN VARCHAR2 IS
   v_cod_usuario ge_autorizadores.cod_usuario%type;
   v_cod_usu_oficial varchar2(50);
cursor aut is
   select cod_usuario
     from ge_autorizadores
    where nvl(cod_tra_padre,nvl(p_cod_tra_padre,-1)) = nvl(p_cod_tra_padre,-1)
      and nvl(cod_mod_padre,nvl(p_cod_mod_padre,-1)) = nvl(p_cod_mod_padre,-1)
      and nvl(cod_mad_padre,nvl(p_cod_mad_padre,-1)) = nvl(p_cod_mad_padre,-1)
      and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
      and nvl(monto,nvl(p_monto,-1)) >= nvl(p_monto,-1)
      --and nvl(v_cod_usu_oficial,cod_usuario) = cod_usuario
      order by fue_ver_sesion(cod_usuario); -- que primero tome los activos ;
BEGIN
   if p_nro_cuenta is not null then
      -- voy a buscar el gestor de la cuenta
      select cod_usu_oficial
        into v_cod_usu_oficial
        from ge_clientes a
       where exists (select 0 from ge_cta_clientes b
                      where b.nro_cuenta = p_nro_cuenta
                        and b.cod_persona = a.cod_persona
                        and b.relacion = 'P');
   end if;
   OPEN aut;
   FETCH aut INTO v_cod_usuario;
   CLOSE aut;
   if v_cod_usuario is null then
      raise no_data_found;
   end if;
   return v_cod_usuario;
EXCEPTION
   when no_data_found then
      raise_application_error(-20000,
      'No existe usuario autorizador definido');
END;
--- Recalcular cupon de CDA
PROCEDURE PR_CAL_INT_CUPONES
 (P_NRO_CUENTA IN GE_AUTORIZACIONES.NRO_CUENTA%TYPE
 ,P_FEC_APERTURA IN AH_CTA_CERTIFICADOS.FEC_APERTURA%TYPE
 ,P_FEC_VENCIMIENTO IN AH_CTA_CERTIFICADOS.FEC_VENCIMIENTO%TYPE
 ,P_CAPITAL IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE
 ,P_VAL_TASA IN GE_TAS_FECHAS.VAL_TASA%TYPE
 ) IS
   --- Cursor de cupones
   cursor c_ah_cupones is
   select fec_vencimiento, mto_interes, rowid
     from ah_cupones
    where nro_cuenta = p_nro_cuenta
    order by fec_vencimiento for update;
   --- Variables auxiliares para el calculo
   v_fec_vto_ant ah_cupones.fec_vencimiento%type;
   v_mto_interes ah_cupones.mto_interes%type;
   v_dias number(05);
   v_int_calculado number(18,2) := 0;
   v_int_suma      number(18,2) := 0;
   v_ult_rowid     varchar2(100);
   v_redondeo      number(5);
   v_cod_modulo    ge_cuentas.cod_modulo%type;
   v_cod_modalidad ge_cuentas.cod_modalidad%type;
   v_cod_moneda    ge_cuentas.cod_moneda%type;
BEGIN
   --- Obtener datos de la cuenta para recuperar la moneda y el redondeo
   begin
      select cod_modulo, cod_modalidad, cod_moneda
        into v_cod_modulo, v_cod_modalidad, v_cod_moneda
        from ge_cuentas
       where nro_cuenta = p_nro_cuenta;
      exception
         when no_data_found then
            raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no existe en ge_cuentas');
   end;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_COD_MODULO,v_COD_MODalidad,v_COD_moneda);
   -- calculo el total del interes
   v_int_calculado := Round(p_capital *
                           (p_fec_vencimiento-p_fec_apertura) *
                            p_val_tasa / 36500, v_redondeo);
   v_fec_vto_ant := p_fec_apertura;
   for cup in c_ah_cupones loop
      v_dias := cup.fec_vencimiento - v_fec_vto_ant;
      v_mto_interes := Round(((P_CAPITAL*v_dias *P_VAL_TASA)/36500), v_redondeo);
      update ah_cupones
         set mto_interes = v_mto_interes
       where rowid = cup.rowid;
      --- acumulo los montos de interes calculados
      v_int_suma := nvl(v_int_suma,0) + nvl(v_mto_interes,0);
      v_ult_rowid := cup.rowid;
      --- Cargar fecha de vencimiento anterior
      v_fec_vto_ant := cup.fec_vencimiento;
   end loop;
   -- si hay diferencia entre el int. calculado y el de los cupones, se ajusta el ultimo
   if v_int_calculado <> v_int_suma then
      update ah_cupones
         set mto_interes = nvl(mto_interes,0) +
                           (nvl(v_int_calculado,0) - nvl(v_int_suma,0))
       where rowid = v_ult_rowid;
   end if;
END;
--- Anular movimiento de autorizacion
PROCEDURE PR_ANU_MOVIMIENTO
  (P_COD_USUARIO GE_AUT_PEDIDOS.COD_USUARIO%TYPE
  ,P_FECHA GE_AUT_PEDIDOS.FECHA%TYPE
  ,P_HORA GE_AUT_PEDIDOS.HORA%TYPE
  ) IS
   -- Cursor de movimientos en 'X' para el pedido
   CURSOR c_mov_pedidos IS
   SELECT nro_cuenta, cod_tasa, rowid
     FROM ge_movimientos
    WHERE cod_usuario = p_cod_usuario
      and fecha = p_fecha
      and hora = p_hora
      and estado = 'X';
BEGIN
   for reg in c_mov_pedidos loop
       update ge_movimientos
          set reversado = 'S',
              cod_usu_reversion = user,
              hor_reversion = to_char(sysdate,'HH24:MI:SS')
        where rowid = reg.rowid;
     if not pag_aut.fu_obt_ped_pendiente(reg.nro_cuenta) then
        --- Si ya no posee autorizacion pendiente la cuenta
        update ah_cta_certificados
           set aut_pendiente = 'N'
         where nro_cuenta = reg.nro_cuenta
           and aut_pendiente = 'S';
     end if;
   end loop;
END;

--- Generar autorizacion
PROCEDURE PR_GEN_AUTORIZACION
  (P_COD_USUARIO GE_AUT_PEDIDOS.COD_USUARIO%TYPE
  ,P_FECHA GE_AUT_PEDIDOS.FECHA%TYPE
  ,P_HORA GE_AUT_PEDIDOS.HORA%TYPE
  ,P_COD_USU_AUTORIZADOR GE_AUT_PEDIDOS.COD_USU_AUTORIZADOR%TYPE
  ,P_FEC_VENCIMIENTO GE_AUTORIZACIONES.FEC_VENCIMIENTO%TYPE
  ,P_OBSERVACION GE_AUTORIZACIONES.OBSERVACION%TYPE
  ) IS
   -- Cursor de movimientos en 'X' para el pedido
   CURSOR c_mov_pedidos IS
   SELECT cod_usuario, fecha,
          hora, nro_secuencia, nro_cuenta,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_transaccion, cod_modulo, cod_modalidad,
          cod_tasa,monto, rowid
     FROM ge_movimientos
    WHERE cod_usuario = p_cod_usuario
      and fecha = p_fecha
      and hora = p_hora
      and estado = 'X'
      and reversado = 'N'
      and cod_usu_autorizador is null;
   v_cod_autorizacion ge_autorizaciones.cod_autorizacion%type;
BEGIN
   for reg in c_mov_pedidos loop
      --- Generar autorizacion
      begin
         select s_cod_autorizacion.nextval
           into v_cod_autorizacion
           from dual;
      exception
         when others then
            raise_application_error(-20000,'Secuencia Autorizacion '||sqlerrm);
      end;
      insert into ge_autorizaciones
      (COD_AUTORIZACION, COD_USUARIO, FECHA,
       HORA, NRO_SECUENCIA, NRO_CUENTA,
       COD_TRA_PADRE, COD_MOD_PADRE, COD_MAD_PADRE,
       COD_TRANSACCION, COD_MODULO, COD_MODALIDAD,
       VALOR, FEC_VENCIMIENTO,
       OBSERVACION, COD_USU_AUTORIZADOR)
      values
      (v_cod_autorizacion, reg.cod_usuario, reg.fecha,
       reg.hora, reg.nro_secuencia, reg.nro_cuenta,
       reg.cod_tra_padre, reg.cod_mod_padre, reg.cod_mad_padre,
       reg.cod_transaccion, reg.cod_modulo, reg.cod_modalidad,
       nvl(reg.cod_tasa,reg.monto), p_fec_vencimiento,
       p_observacion, P_COD_USU_AUTORIZADOR
      );
      --- Actualizar movimiento autorizado
       update ge_movimientos
          set reversado = 'N',
              cod_usu_autorizador = p_cod_usu_autorizador,
              cod_autorizacion = v_cod_autorizacion
        where rowid = reg.rowid;
   end loop;
END;
--- Recuperar persona del pedido para generar Agenda
FUNCTION FU_OBT_PER_PEDIDO
  (P_COD_USUARIO GE_AUT_PEDIDOS.COD_USUARIO%TYPE
  ,P_FECHA GE_AUT_PEDIDOS.FECHA%TYPE
  ,P_HORA GE_AUT_PEDIDOS.HORA%TYPE
  )
RETURN VARCHAR2 IS
   v_cod_persona ba_personas.cod_persona%type;
BEGIN
   SELECT cta.cod_persona
     INTO v_cod_persona
     FROM ge_movimientos mov, ge_cta_clientes cta
    WHERE mov.cod_usuario = p_cod_usuario
      and mov.fecha = p_fecha
      and mov.hora = p_hora
      and mov.estado = 'X'
      and mov.nro_cuenta = cta.nro_cuenta
      and cta.relacion = 'P'
      and cod_usu_autorizador is null
      and mov.reversado = 'N'
      and rownum = 1;
   RETURN v_cod_persona;
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe persona para el pedido de autorizacion');
END;
--- Verificar autorizacion
FUNCTION FU_VER_AUTORIZACION
  (P_NRCUENT GE_AUTORIZACIONES.NRO_CUENTA%TYPE
  ,P_CDTRANS GE_AUTORIZACIONES.COD_TRANSACCION%TYPE
  ,P_FCTRANS GE_AUTORIZACIONES.FEC_UTILIZACION%TYPE
  ,P_HRMOVIM GE_AUTORIZACIONES.HOR_UTILIZACION%TYPE
  ,P_PROCESA GE_AUTORIZACIONES.EXIMIDO%TYPE
  )
RETURN VARCHAR2 IS
  v_encontro ge_movimientos.estado%type;
BEGIN
  If p_procesa = 'S' Then
    update ge_autorizaciones
       set cod_usu_utilizador = user,
           fec_utilizacion = p_fctrans,
           hor_utilizacion = p_hrmovim
     where nro_cuenta = p_nrcuent
       and cod_transaccion = p_cdtrans
       and eximido = 'S';

     IF SQL%FOUND THEN
        v_encontro := 'S';
     ELSE
        v_encontro := 'N';
     END IF;
  Else
    Begin
      select 'S'
        into v_encontro
        from ge_autorizaciones
        where nro_cuenta = p_nrcuent
         and cod_transaccion = p_cdtrans
          and eximido = 'S';
    Exception
      When NO_DATA_FOUND Then
        v_encontro := 'N';
    End;
  End If;
  Return v_encontro;
END;

end PAG_AUT;
/

