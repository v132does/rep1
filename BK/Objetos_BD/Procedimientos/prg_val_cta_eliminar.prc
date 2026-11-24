CREATE OR REPLACE PROCEDURE IT.prg_val_cta_eliminar
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 )
 IS

/* Verifica si el estado de la cuenta es X o A. */
FUNCTION LF_VER_EST_CUENTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN;
/* Verificar si la cuenta es débito de alguna otra. */
FUNCTION LF_VER_CTA_DEBITO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
--Sólo modulos 3 (31 y 33) y 4 cda y cta_cte
--validar que la cuenta se encuentre en estado X o A.
--que no exista como cta de débito de otra cuenta.

/* Verifica si el usuario puede eliminar cta de funionarios*/
FUNCTION LF_ELI_CTA_EMPLEADO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN;

v_msj varchar2(500) := 'Cuenta no permite eliminación.' ;

/* Verifica si el estado de la cuenta es X o A. */
FUNCTION LF_VER_EST_CUENTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS
vaux varchar2(1);
begin
   v_msj := 'Estado de la Cuenta no permite eliminación';
   select 'x'
   into vaux
   from ge_cuentas a
   where ((estado in ('X','A') and cod_modulo in (3,4)) or (estado in ('S','C') and cod_modulo = 8)
        --wa:19/10/2010 solo puede eliminar Solicitado en Mesa de Dinero
        or (estado = 'S' and cod_modulo = 10))
    and nro_cuenta = p_nro_cuenta;

   if p_cod_modulo = 8 then
      if p_cod_modalidad = 81 then
        begin
          select 'x'
            into vaux
            from cx_cta_importaciones
           where nro_cuenta = p_nro_cuenta
             and (estado = 'S' or
                 (estado = 'C' and fec_solicitud = fec_cancelacion));
        exception
           when others then
              return false;
        end;
        return true;
     else
        return true;
     end if;
   --wa:20/10/2010 Para Mesa de Dinero
   elsif p_cod_modulo = 10  then
      select 'x'
        into vaux
         from MD_CTA_DOCUMENTOS t
           where t.nro_cuenta = p_nro_cuenta
            and t.estado      = 'S';
       return true;
   else
      v_msj := 'La cuenta posee algun saldo pendiente. Verifique';
   end if;
   if p_cod_modalidad in (31,334) then
      select 'x'
        into vaux
        from ah_cta_vistas t
       where nro_cuenta = p_nro_cuenta
         and nvl(sal_total,0) = 0
         and nvl(sal_bloqueado,0) = 0
         and nvl(sal_retenido,0) = 0
         and nvl(mto_deb_pendientes,0) = 0
         and nvl(mto_cre_pendientes,0) = 0
         and nvl(mto_cre_a_confirmar,0) = 0;
   elsif p_cod_modalidad in (32,37,38) then
      select 'x'
        into vaux
        from ah_cta_plazos t
       where nro_cuenta = p_nro_cuenta
         and nvl(sal_total,0) = 0
         and nvl(sal_bloqueado,0) = 0
         and nvl(sal_retenido,0) = 0;
   elsif p_cod_modalidad in (33,34,35,36) then
      select 'x'
        into vaux
        from ah_cta_certificados t
       where nro_cuenta = p_nro_cuenta
         and nvl(sal_total,0) = 0
         and nvl(sal_bloqueado,0) = 0
         and nvl(sal_retenido,0) = 0;
      v_msj := 'Cuenta tiene asignado ya tiene asignado Numero de CDA';
      select 'x'
        into vaux
        from ah_cta_certificados t
       where nro_cuenta = p_nro_cuenta
         and nro_certificado is null;
   elsif p_cod_modalidad = 41 then
      select 'x'
        into vaux
        from cc_cta_corrientes t
       where nro_cuenta = p_nro_cuenta
         and nvl(sal_total,0) = 0
         and nvl(sal_bloqueado,0) = 0
         and nvl(sal_retenido,0) = 0
         and nvl(mto_deb_pendientes,0) = 0
         and nvl(mto_cre_pendientes,0) = 0
         and nvl(mto_cre_a_confirmar,0) = 0;
   else
      return false;
   end if;
   return true;
exception
   when others then
      return false;
end;
/* Verificar si la cuenta es débito de alguna otra. */
FUNCTION LF_VER_CTA_DEBITO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
--ver si existe en alguna emitir msj q existe y de qué cuenta es
cursor pres is
   select nro_cuenta
   from pr_cta_prestamos
   where nro_cta_debito = p_nro_cuenta;
cursor sol is
   select nro_solicitud
   from pr_solicitudes
   where nro_cta_debito = p_nro_cuenta;
cursor cob is
   select nro_cuenta
   from ta_cobros
   where nro_cta_debito = p_nro_cuenta;
cursor tarj is
   select nro_cuenta
   from ta_cta_tarjetas
   where nro_cta_debito = p_nro_cuenta;

v_cta ge_cuentas.nro_cuenta%type;
v_msj varchar2(500):='Cta. utilizada como Cta. de Débito ';
begin
   for reg in pres loop
      v_cta :=reg.nro_cuenta;
      v_msj:= v_msj||' del prést. '||v_cta;
      exit;
   end loop;
   --si no encontró préstamo, seguir buscando
   if v_cta is null then
      for reg in sol loop
         v_cta :=to_char(reg.nro_solicitud);
         v_msj:= v_msj||'de la Solicitud de Prést. '||v_cta;
         exit;
      end loop;
   end if;
   --si no encontró titular tarj, seguir buscando
   if v_cta is null then
      for reg in tarj loop
         v_cta :=reg.nro_cuenta;
         v_msj:= v_msj||'de la Tarj. '||v_cta;
         exit;
      end loop;
   end if;
   --si no encontró tarj, seguir buscando
   if v_cta is null then
      for reg in cob loop
         v_cta :=reg.nro_cuenta;
         v_msj:= v_msj||'en cobro de Tarj. '||v_cta;
         exit;
      end loop;
   end if;
   --si no encontró cobro tarj, puede borrar
   if v_cta is null then
      return 'OK';
   else
      return v_msj;
   end if;
exception
   when others then
      raise_application_error(-20001,'Verif.Cta Débito -'||sqlerrm);
end;

/* Verificar si la cuenta tiene movimientos. */
FUNCTION LF_VER_MOV_CUENTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS
v_existe number;
begin
   select 1
   into v_existe
   from gv_movimientos
   where nvl(monto,0) <> 0
   and nro_cuenta = p_nro_cuenta
   and reversado = 'N';
   return false;
exception
   when no_data_found then
      return true;
   when too_many_rows then
      return false;
   when others then
      return false;
end;
/* Verificar si la cuenta tiene débitos pendientes. */
FUNCTION LF_VER_DEB_PENDIENTE
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
cursor ver is
select 'GE_DEB_PENDIENTES' tabla, 'La Cta. posee Débitos Pendientes' descri
from GE_DEB_PENDIENTES
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_BANCOS' tabla,'Cta. utilizada como conciliatoria' descri
from AH_CTA_BANCOS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_CAJEROS' tabla,'Cta. utilizada en Cajeros Automáticos' descri
from AH_CTA_CAJEROS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_FICTICIAS' tabla,'Cta. utilizada en Cuentas Ficticias' descri
from AH_CTA_FICTICIAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_RESPALDADAS' tabla,'Cta. utilizada en Entidades Respaldadas' descri
from AH_CTA_RESPALDADAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_TAR_DEBITOS' tabla, 'Cta. utilizada en Tarjetas de Débito' descri
from AH_TAR_DEBITOS
where nro_cuenta = p_nro_cuenta
and cod_est_solicitud not in (1,16)
and rownum=1
union
select 'CC_CHEQUERAS' tabla,'La Cta. posee Chequeras' descri
from CC_CHEQUERAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'CC_LIN_SOBREGIROS' tabla,'La Cta. posee Líneas de Sobregiro' descri
from CC_LIN_SOBREGIROS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'CC_SOL_CHEQUERAS' tabla,'La Cta. posee Solicitudes de Chequeras' descri
from CC_SOL_CHEQUERAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union --DYDMR-5548 (ALV-02/2017)
select 'GE_PAQ_CUENTAS' tabla,'La Cta. tiene paquetes asociados' descri 
from GE_PAQ_CUENTAS
where nro_cuenta = p_nro_cuenta
and rownum=1;

v_msj varchar2(1000);
begin
   for reg in ver loop
      v_msj:= reg.descri ||'<'||reg.tabla||'>';
      exit;
   end loop;
   if v_msj is null then
      return 'OK';
   else
      return v_msj;
   end if;
exception
   when others then
      raise_application_error(-20002,'Verif.Cta -'||sqlerrm);
end;

/* Verificar si la cuenta está en ctas combinadas. */
FUNCTION LF_VER_CTA_COMBINADA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS
--ver si existe en alguna emitir msj q existe y de qué cuenta es
v_existe number;
begin
   select 1
   into v_existe
   from cc_cta_combinadas
   where nro_cta_ahorro = p_nro_cuenta
   union
   select 1
   from cc_cta_combinadas
   where nro_cta_cte = p_nro_cuenta;
   return false;
exception
   when no_Data_found then
      return true;
   when too_many_rows then
      return false;
   when others then
      return false;
end;

/* Verifica si el usuario puede eliminar cta de funionarios*/
FUNCTION LF_ELI_CTA_EMPLEADO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS

 v_cod_persona ba_personas.cod_persona%type;

begin
  select cod_persona
    into v_cod_persona
    from ge_cta_clientes
    where nro_cuenta = p_nro_cuenta
      and relacion = 'P';

  if fue_obt_ve_cta_cli(user, v_cod_persona) = 'N' then
    return false;
  else
    return true;
  end if;
exception
  when others then
    return false;
end;

begin
   --sólo ahorros vistas, cdas y ctas ctes, comex
  --wa:19/10/2010 se agregó el modulo 10 para Mesa de Dinero
   if p_cod_modulo not in (3, 4, 8,10) then
      raise_application_error(-20011,'Solo pueden eliminarse Ctas de Ahorro, Corrientes, CCI o CCE o Mesa de Dinero');
   elsif p_cod_modulo = 3 then
      if p_cod_modalidad not in (31,33,34,35,334) then
        raise_application_error(-20011,'Sólo pueden eliminarse Ahorros Vista o CDA/Titulos');
      end if;
   end if;
   if LF_VER_EST_CUENTA(p_nro_cuenta) then
      -- Verifica si el usuario puede eliminar cta de funionarios
      if not LF_ELI_CTA_EMPLEADO(p_nro_cuenta) then
         raise_application_error(-20010,'Cta. de Funcionario ');
      end if;
      --puede continuar el estado es X o A
      v_msj := LF_VER_CTA_DEBITO(p_nro_cuenta);
      if v_msj <> 'OK' THEN
         raise_application_error(-20011,v_msj);
      end if;
      --verifica que no exista en cuentas combinadas
      if not LF_VER_CTA_COMBINADA(p_nro_cuenta) then
         raise_application_error(-20022,'Cta. utilizada en Ctas. Combinadas ');
      end if;
      --verificar que no existan movimientos de dinero de la cuenta para eliminar
      if not LF_VER_MOV_CUENTA(p_nro_cuenta) then
         raise_application_error(-20022,'La Cta. ya posee Movimientos ');
      end if;
      --verifica que no exista en las tablas
      v_msj := LF_VER_DEB_PENDIENTE(p_nro_cuenta);
      if v_msj <> 'OK' THEN
        raise_application_error(-20022,v_msj);
      end if;
   else
      raise_application_error(-20011,v_msj);
   end if;
end;
/

