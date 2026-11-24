CREATE OR REPLACE PACKAGE BODY IT."PAI_INT" is
  -- Function and procedure implementations
function fu_obt_val_tasa
     (p_cod_modulo in ge_cuentas.cod_modulo%type,
      p_cod_modalidad in ge_cuentas.cod_modalidad%type,
      p_cod_oficina in ge_cuentas.cod_oficina%type,
      p_nro_cuenta in ge_cuentas.nro_cuenta%type,
      p_cod_moneda in ge_cuentas.cod_moneda%type,
      p_saldo in ge_cuentas.sal_contable%type,
      p_tas_personalizada in ge_cuentas.tas_personalizada%type,
      p_cod_tasa in ge_cuentas.cod_tasa%type,
      p_fec_apertura in ge_cuentas.fec_apertura%type)
return number is
  begin
     return fug_obt_val_tasa(p_cod_modulo, p_cod_modalidad, p_cod_oficina, p_nro_cuenta,
            p_cod_moneda, p_saldo, p_tas_personalizada, p_cod_tasa, null, p_fec_apertura);
  exception
     when others then return 0;
     null;
  end;


--Obtiene el tipo de deposito
function fu_obt_tip_deposito
     (p_cod_modalidad in ge_cuentas.cod_modalidad%type,
     p_cod_moneda in ba_monedas.cod_moneda%type)
return number
is
tip_deposito number;
begin
case
    when p_cod_modalidad=32 and p_cod_moneda='GS' then
         tip_deposito:=10;
    when p_cod_modalidad=32 and p_cod_moneda!='GS' then
         tip_deposito:=65;
    when p_cod_modalidad=33 and p_cod_moneda='GS' then
         tip_deposito:=15;
    when p_cod_modalidad=33 and p_cod_moneda!='GS' then
         tip_deposito:=60;
    else
         tip_deposito:=0;
end case;
return(tip_deposito);
exception
    when others then
         raise_application_error(-20000,'No se encuentra el Tipo de deposito MOD: '||p_cod_modalidad||' MOneda: '||p_cod_moneda||sqlerrm);

end;

--Obtiene Si es Conjunta o Indistinta
function fu_obt_tip_relacion
     (p_nro_cuenta in ge_cuentas.nro_cuenta%type)
return char
is
tip_relacion char;
begin
     select a.relacion into tip_relacion
     from ge_cta_clientes a
     where a.nro_cuenta=p_nro_cuenta
     and a.relacion in('Y','O')
     and rownum=1;
     case
         when tip_relacion='Y' then
              return('C');
         when tip_relacion='O' then
              return('I');

     end case;


exception
    when  others then
          return null;
end;

--Determina si la cuenta esta o no pignorada
function fu_ver_pignoracion
     (p_nro_cuenta in ge_cuentas.nro_cuenta%type) return number
is

var char;

begin
   /* cambiado el 20090910
    select 'S' into  var
    from pr_gar_cash a
    where p_nro_cuenta=a.nro_cta_referencia
          and rownum=1;
    */
    select 'S' into  var
    from ge_bloqueos g
    where p_nro_cuenta=g.nro_cuenta
          and g.cod_causa = 230
          and  rownum = 1;
    if var='S' then
               return(99);
    end if;
exception
    when others then
          return(0);
end;


--Obtiene Devengado del CDA
FUNCTION FUI_OBT_DEV_CDA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_CAPITAL IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE
 ,P_FEC_APERTURA IN AH_CTA_CERTIFICADOS.FEC_APERTURA%TYPE
 ,P_FEC_CALCULO IN DATE
 )
 RETURN NUMBER
 is
 begin
 return(pas_bcp.fu_obt_dev_cda(p_nro_cuenta ,
                        p_capital,
                        p_fec_apertura,
                        p_fec_calculo));
 exception
     when others then return 0;
     null;
 end;

--Obtiene la Clase del Cliente segun BCP
FUNCTION fu_obt_cla_cliente
  (p_cod_persona in ge_clientes.cod_persona%type
  )
return number
is
clase number;
begin
       select b.grubcp into clase
       from ge_clientes a, equiv_grubcp b
       where p_cod_persona=a.cod_persona
       and b.cod_tip_deudor = a.cod_tip_deudor
       and b.cod_sec_contable = a.cod_sec_contable;
       return(clase);
exception
       when others then
            return(99);
            raise_application_error(-20000,'No existe la Persona:'||p_cod_persona||sqlerrm);

end;


--Obtiene la Cuenta Contable
FUNCTION FU_OBT_CTA_CONTABLE
  (P_COD_RUBRO IN CB_RUBROS.COD_RUBRO%TYPE)
  RETURN VARCHAR2
IS
CUENTA VARCHAR2(20);
BEGIN
       SELECT A.COD_RUB_EXTERNO INTO CUENTA
       FROM CB_RUBROS A
       WHERE A.COD_RUBRO=P_COD_RUBRO;
       RETURN CUENTA;
EXCEPTION
       WHEN OTHERS THEN
            return null;
END;

--Funcion que trae el estado de la cuenta de un cliente
FUNCTION FU_OBT_EST_CUENTA(P_COD_MODALIDAD  IN GE_EST_CUENTAS.COD_MODALIDAD%TYPE,
                           P_ESTADO  IN GE_EST_CUENTAS.ESTADO%TYPE)
RETURN CHAR
IS
ESTADO CHAR;

BEGIN
     SELECT A.ACTIVO INTO ESTADO
     FROM GE_EST_CUENTAS A
     WHERE A.COD_MODALIDAD=P_COD_MODALIDAD
     AND A.ESTADO=P_ESTADO;
     CASE
        WHEN ESTADO='S' THEN
             RETURN'0';
        ELSE
             RETURN'C';
     END CASE;
exception
     when others then
          Return null;

END;

-- OBTIENE LA FECHA DE INICIO DEL DEVENGAMIENTO
FUNCTION FU_SIM_OBT_FECHAINI(vnro_documento varchar2, vnro_cuota number) return date is
  vfecha      date;
begin

     If vnro_cuota = 1 then

          select fec_inicio  into vfecha
          from md_cta_documentos
          where nro_cuenta = vnro_documento;

     else
          select fec_vencimiento  into vfecha
          from md_doc_detalles
          where nro_cuenta = vnro_documento
          and nro_cuota= vnro_cuota - 1;

     end if;

   return(vfecha);

end;

--OBTIENE EL TIPO DE CUENTA PARA LA TABLA ARBOSUBTN
FUNCTION FU_SIM_OBT_TIP_CUENTA(v_cta in number, v_moneda  in  varchar2) return number is
  tcta        number;
begin
      if v_cta = 01 then
           if v_moneda = 'GS' then
                 tcta := 210100;
           else
                 tcta := 215000;
           end if;
     end if;

     if v_cta = 02 then
        if v_moneda = 'GS' then
           tcta := 210500;
        else
           tcta := 215500;
        end if;
     end if;

     if v_cta = 03 then
        if v_moneda = 'GS' then
           tcta := 211500;
        else
           tcta := 216000;
        end if;
     end if;

return (tcta);

end;


--OBTIENE FECHA INICIO DE CUPONES
FUNCTION FU_SIM_OBT_FECHAINI_CUPONES(vnro_cuenta varchar2, vnro_cupon number) return date is
  vfecha      date;
begin

     If vnro_cupon = 1 then

          select fec_hor_emision into vfecha
          from ah_cupones
          where nro_cuenta = vnro_cuenta
          and nro_cupon = 1;

     else

          select fec_vencimiento into vfecha
          from ah_cupones
          where nro_cuenta = vnro_cuenta
          and nro_cupon = vnro_cupon - 1;

     end if;

   return(vfecha);
Exception
  when no_data_found then
      select min(fec_inicio) into vfecha
      from ah_devengados
      where nro_cuenta = vnro_cuenta;
      return (vfecha);

end;

--OBTIENE EL MONTO AH_DEVENGADO POR MEDIO DEL NUMERO DE CUENTA Y LA FECHA DE INICIO DE LA CUOTA


function FU_SIM_OBT_MTO_ADEV(vnro_cuenta  varchar2, vnro_cupon  number) return number is
  vmonto number(15,2);
begin

 select nvl(d.mto_devengado,0) into vmonto
 from
(select rownum fila, a.mto_dev_acumulado mto_devengado, a.fec_inicio  from ah_devengados a where a.nro_cuenta = vnro_cuenta
 order by a.fec_inicio asc) d,
(select  rownum fila,  c.nro_cuenta cuenta, c.nro_cupon cupon from ah_cupones c
 where c.nro_cuenta = vnro_cuenta order by c.nro_cupon asc) b where d.fila(+) = b.fila and b.cupon = vnro_cupon;

  return(vmonto);
end;

--OBTIENE EL MONTO AH_DEVENGADO POR MEDIO DEL NUMERO DE CUENTA Y LA FECHA DE INICIO DE LA CUOTA OLFMAECDA


function FU_SIM_OBT_MTO_ADEV_CDA(vnro_cuenta  varchar2, vnro_cupon  number, vfecha_apertura date) return number is
  vmonto number(15,2);
begin

-- orden ascendente
 select nvl(d.mto_devengado,0) into vmonto
 from
(select rownum fila, a.mto_dev_acumulado mto_devengado, a.fec_inicio  from ah_devengados a where a.nro_cuenta = vnro_cuenta
 and a.fec_inicio >= vfecha_apertura order by a.fec_inicio asc) d,
(select  rownum fila,  c.nro_cuenta cuenta, c.nro_cupon cupon from ah_cupones c
 where c.nro_cuenta = vnro_cuenta order by c.nro_cupon asc) b where d.fila(+) = b.fila and b.cupon = vnro_cupon;

 -- orden descendente, deja error x cupones borrados para las cuotas viejas,
 -- 20100528 se vuelve a la version anterior, los errores en cupones viejos tambien crean problemas en la AS400
 /*select nvl(d.mto_devengado,0) into vmonto
 from
(select rownum fila, x.* from
(select  a.mto_dev_acumulado mto_devengado, a.fec_inicio  from ah_devengados a where a.nro_cuenta = vnro_cuenta
 and a.fec_inicio >= vfecha_apertura order by a.fec_inicio desc) x ) d,
(select rownum fila, y.* from
(select  c.nro_cuenta cuenta, c.nro_cupon cupon from ah_cupones c
 where c.nro_cuenta = vnro_cuenta order by c.nro_cupon desc) y ) b  where d.fila(+) = b.fila and b.cupon = vnro_cupon;*/


  return(vmonto);
end;



--OBTIENE EL MONTO MD_DEVENGADO POR MEDIO DEL NUMERO DE CUENTA Y LA FECHA DE INICIO DE LA CUOTA

function FU_SIM_OBT_MTO_MDEV(vnro_cuenta  varchar2, vfecha_inicio  date) return number is
  vmonto number(15,2);
begin

  select mto_dev_acumulado into vmonto
  from md_devengados
  where nro_cuenta = vnro_cuenta
  and fec_inicio = vfecha_inicio;


  return(vmonto);
end;

-- OBTIENE LA FECHA DE INICIO DE MD_DOC_DETALLES
FUNCTION FU_SIM_OBT_FECHAINI_DOC_DET(vnro_documento varchar2, vnro_cuota number) return date is
  vfecha      date;
begin

     If vnro_cuota = 1 then

      select min(fec_inicio) into vfecha
      from md_devengados
      where nro_cuenta = vnro_documento;
      return (vfecha);

     else
          select fec_vencimiento  into vfecha
          from md_doc_detalles
          where nro_cuenta = vnro_documento
          and nro_cuota= vnro_cuota - 1;

     end if;

   return(vfecha);
   Exception
  when no_data_found then
      select min(fec_inicio) into vfecha
      from md_devengados
      where nro_cuenta = vnro_documento;
      return (vfecha);

end;

FUNCTION FU_SIM_OBT_DOCUMENTO_TRNCMBPRE(VTRANSACCION IN NUMBER,VMODALIDAD IN NUMBER,
VPADRE IN NUMBER,VRUBRO IN VARCHAR2,VHORA IN VARCHAR2,VFECHA IN DATE) return number is
  VAR_DOCUMENTO number;
  VAR_TIPO VARCHAR2(1);
begin
/* RTIPO ('E=EFE, C=CHQ cargo otro, T=TRF, O=OTR')
afe_posicion = 'E'(efectivo), 'O' Si es 'O' o 'N', buscar en afe_transferencia = 'S'='T',
 si en este ultimo caso tiene dato de cheque y es otro banco 'C' sino siempre 'O'*/

  SELECT  DECODE(lc.afe_posicion,'E','E','O',decode(lc.afe_transferencia,'S','T')) INTO VAR_TIPO
  FROM  lv_cambios lvc, lc_tip_operaciones lc
  where lvc.cod_mad_padre= lc.cod_mad_hijo
  and lvc.cod_transaccion= lc.cod_transaccion
  and lvc.cod_modalidad= lc.cod_modalidad
  and lvc.cod_tip_ope_cambio= lc.cod_tip_operacion

  and lvc.cod_transaccion= Vtransaccion
  and lvc.cod_modalidad= Vmodalidad
  and lvc.cod_mad_padre= Vpadre
  and lvc.cod_rubro= Vrubro
  and lvc.hora= Vhora
  and lvc.fecha= Vfecha;

  IF VAR_TIPO= 'T' THEN
    --si tiene dato de cheque y es otro banco 'C' sino siempre 'O'
    --con este select puedo saber si es un dato de cheque y obtener el nro de documento con la
    --secuencia 1
        --DEVUELVE EL NRO DE DOCUMENTO
    select nro_documento3 into VAR_DOCUMENTO
    from ge_movimientos e
    where e.cod_tip_ope_cambio in (18,57,87)
/*    and e.cod_transaccion= vtransaccion
    and e.cod_modalidad= vmodalidad
    and e.cod_mad_padre= vpadre
    and e.cod_rubro= vrubro
    and e.fecha= vfecha*/
    and e.hora= vhora
    and e.nro_secuencia=1;

  END IF;

  return(VAR_DOCUMENTO);

end;


FUNCTION FU_SIM_OBT_TIPO_TRNCMBPRE(VTRANSACCION IN NUMBER,VMODALIDAD IN NUMBER,
VPADRE IN NUMBER,VRUBRO IN VARCHAR2,VHORA IN VARCHAR2,VFECHA IN DATE) return varchar2 is
  VAR_TIPO VARCHAR2(1);
begin
/* RTIPO ('E=EFE, C=CHQ cargo otro, T=TRF, O=OTR')
afe_posicion = 'E'(efectivo), 'O' Si es 'O' o 'N', buscar en afe_transferencia = 'S'='T',
 si en este ultimo caso tiene dato de cheque y es otro banco 'C' sino siempre 'O'*/

  SELECT  DECODE(lc.afe_posicion,'E','E','O',decode(lc.afe_transferencia,'S','T')) INTO VAR_TIPO
  FROM  lv_cambios lvc, lc_tip_operaciones lc
  where lvc.cod_mad_padre= lc.cod_mad_hijo
  and lvc.cod_transaccion= lc.cod_transaccion
  and lvc.cod_modalidad= lc.cod_modalidad
  and lvc.cod_tip_ope_cambio= lc.cod_tip_operacion

  and lvc.cod_transaccion= Vtransaccion
  and lvc.cod_modalidad= Vmodalidad
  and lvc.cod_mad_padre= Vpadre
  and lvc.cod_rubro= Vrubro
  and lvc.hora= Vhora
  and lvc.fecha= Vfecha;

  IF VAR_TIPO= 'T' THEN
    --si tiene dato de cheque y es otro banco 'C' sino siempre 'O'
    --con este select puedo saber si es un dato de cheque
    BEGIN
      --DEVUELVE EL TIPO
    select 'C' INTO VAR_TIPO
    from ge_movimientos e
    where e.cod_tip_ope_cambio in (18,57,87)
/*    and e.cod_transaccion= vtransaccion
    and e.cod_modalidad= vmodalidad
    and e.cod_mad_padre= vpadre
    and e.cod_rubro= vrubro
    and e.fecha= vfecha*/
    and e.hora= vhora
    and e.nro_secuencia=1;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         VAR_TIPO:= 'O';
    END;

  END IF;

  return(VAR_TIPO);

end;

FUNCTION FU_SIM_OBT_CODCORR(COD_BCO_CORRESPONSAL in number, COD_MONEDA in varchar2) return integer is
  Result integer;
begin
  BEGIN
    select ebt.cod_banco_as into Result
    from equiv_bco_trans ebt
    where ebt.cod_banco_it = cod_bco_corresponsal;

  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      /*DECLARE
         v_moneda varchar2;*/
      begin
        select ebt.cod_banco_as INTO Result
        from equiv_bco_trans ebt
        where ebt.cod_banco_it = COD_BCO_CORRESPONSAL
        and UPPER(ebt.nombre_banco) like UPPER('%' || COD_MONEDA || '%');
      exception
         when no_data_found then
            Result:= 0;
      end;
    when no_data_found then
      Result:= 0;
  END;
  return(Result);
end;

function FU_SIM_NORM_CADENA(cadena in varchar2, long in integer) return varchar2 is
  Result varchar2(500);
  AUX varchar2(500) := cadena;
begin
  /*
  Filtro de caracteres especiales
  Para encontrar + valores: select ASCII('/') FROM dual;
  */
  AUX := replace(AUX,CHR(39),''); --'
  /*AUX := replace(AUX,CHR(47),''); --/
  AUX := replace(AUX,CHR(92),''); --\*/
  AUX := replace(AUX,CHR(37),''); --%
  AUX := replace(AUX,CHR(36),''); --$
  AUX := replace(AUX,CHR(38),''); --&
  AUX := replace(AUX,CHR(34),''); --"
  AUX := replace(AUX,CHR(59),''); --;
  AUX := replace(AUX,CHR(58),''); --:
  AUX := replace(AUX,CHR(35),''); --#
  AUX := replace(AUX,CHR(33),''); --!
  AUX := replace(AUX,CHR(183),''); --·
  AUX := replace(AUX,CHR(63),''); --?
  AUX := replace(AUX,CHR(191),''); --¿
  AUX := replace(AUX,CHR(161),''); --¡
  AUX := replace(AUX,CHR(13),''); --ENTER
  AUX := replace(AUX,CHR(10),''); --ENTER

  /*
  Control de Longitud de cadena
  */
  IF length(cadena) > long THEN
    AUX := substr(AUX,1,long);
  END IF;

  Result := AUX;

  return(Result);
end;

--Obtiene numero de secuencia para cheques anulados
function FU_SIM_OBT_SEC_CHE_ANU(v_cuenta in number)
return number is cont number;
begin
if v_cuenta = pai_int.global_nro_cuenta then
pai_int.global_contador := pai_int.global_contador + 1;
else
pai_int.global_nro_cuenta := v_cuenta;
pai_int.global_contador := 1;
end if;
cont:= pai_int.global_contador;
return(cont);

end;

--Obtiene numero de secuencia para montos bloqueados
function FU_SIM_OBT_SEC_MNT_BLQ(v_cuenta in number)
return number is cont number;
begin
if v_cuenta = pai_int.global_nro_cuenta1 then
pai_int.global_contador1 := pai_int.global_contador1 + 1;
else
pai_int.global_nro_cuenta1 := v_cuenta;
pai_int.global_contador1 := 1;
end if;
cont:= pai_int.global_contador1;
return(cont);

end;

--OBTIENE EL TIPO DE CUENTA PARA LAS TABLAS QUE GUARDAN EL TIPO DE CUENTA EN 3P
FUNCTION FU_SIM_OBT_TIP_CUENTA_3P(v_cta in number, v_moneda  in  varchar2) return number is
  tcta        number;
begin
      if v_cta = 01 then
           if v_moneda = 'GS' then
                 tcta := 700;
           else
                 tcta := 709;
           end if;
     end if;

     if v_cta = 02 then
        if v_moneda = 'GS' then
           tcta := 711;
        else
           tcta := 719;
        end if;
     end if;

return (tcta);

end;

--Obtiene numero de secuencia para arpaquete
function FU_SIM_OBT_SEC_ARPAQUETE(v_persona in number)
return number is cont number;
begin
if v_persona = pai_int.global_cod_persona_arpaquete then
pai_int.global_contador_arpaquete := pai_int.global_contador_arpaquete + 1;
else
pai_int.global_cod_persona_arpaquete := v_persona;
pai_int.global_contador_arpaquete := 1;
end if;
cont:= pai_int.global_contador_arpaquete;
return(cont);

end;

--obtiene el tipo de comision para cobros pendientes de comisiones
function FU_SIM_OBT_TIPO_COMISION(v_cod_transaccion in number, v_tipo_cuenta in number, v_moneda  in  varchar2)return number is
  tipo_comision        number;

begin
  case
  when v_cod_transaccion = 528 then
     if v_tipo_cuenta = 1 then
        tipo_comision := 1; -- Mantenimiento de promedio Sdos.Ctas.Ctes.Gs.y US$ hija
     else
        tipo_comision := 7; -- Mantenimiento de promedio Saldos Ahorro Gs. y US$ hija
     end if;
   when v_cod_transaccion = 325 then
        tipo_comision := 1;
   when v_cod_transaccion = 172 then
        tipo_comision := 2;
   when v_cod_transaccion = 137 then
        if v_tipo_cuenta =  1 then --Exceso de mov. en Ctas.Ctes. Gs. (emisión cheques) - no es cliente nomina
           tipo_comision := 2;
        else
           tipo_comision := 21; --Comisión por Extr.de Ahorro en cajas padre, hija
        end if;
   when v_cod_transaccion = 780 then
        tipo_comision := 3;
   when v_cod_transaccion = 532 then
        if v_moneda like 'GS' then
           tipo_comision := 4;-- Emisión de Cheque de Gerencia Gs. hija
        else
           tipo_comision := 5; --Emisión de Cheque de Gerencia USD. hija
        end if;
   when v_cod_transaccion = 305 then
        if v_moneda like 'GS' then
           tipo_comision := 4; --Emisión de Cheque de Gerencia Gs. padre
        else
           tipo_comision := 5; --Emisión de Cheque de Gerencia USD. padre
        end if;
   when v_cod_transaccion = 530 then
        tipo_comision := 6;
   when v_cod_transaccion = 323 then
        tipo_comision := 6;
   when v_cod_transaccion = 324 then
        tipo_comision := 7;
   when v_cod_transaccion = 341 then
        tipo_comision := 8;
   when v_cod_transaccion = 564 then
        tipo_comision := 9;
   when v_cod_transaccion = 148 then
        tipo_comision := 10;
   when v_cod_transaccion = 5021 then
        tipo_comision := 11;
   when v_cod_transaccion = 540 then
        tipo_comision := 12;
   when v_cod_transaccion = 330 then
        tipo_comision := 12;
   when v_cod_transaccion = 794 then
        tipo_comision := 13;
   when v_cod_transaccion = 796 then
        tipo_comision := 22;
   when v_cod_transaccion = 598 then
        tipo_comision := 23;
   when v_cod_transaccion = 797 then
        tipo_comision := 24;
   when v_cod_transaccion = 4105 then
        tipo_comision := 25;
   when v_cod_transaccion = 799 then
        tipo_comision := 89;
   else
        tipo_comision := 99;
end case;


return (tipo_comision);

end;

--obtiene rubro contable

FUNCTION SIMGIA_FUNC_OBT_RUBRO_CONTABLE(v_cod_tip_asiento in number,
v_cod_moneda in varchar2, v_tip_movimiento varchar2,v_cod_sec_contable in varchar2, v_ind_residente in varchar2)
return varchar2
is
v_cod_rubro varchar2(15);
begin

select gta.cod_rubro into v_cod_rubro
from ge_tip_asientos gta
where gta.cod_tip_asiento = v_cod_tip_asiento and gta.cod_moneda = v_cod_moneda and gta.tip_movimiento = v_tip_movimiento and gta.cod_sec_contable = v_cod_sec_contable and gta.ind_residente = v_ind_residente;

return(v_cod_rubro);

END;

-- Crea archivo de texto cc canceladas
procedure cccanceladas_txt is
begin
prg_gen_archivo_txt('CTASCANIT.TXT','select lpad(sc.NSUC,2,0)||lpad(sc.NCTA,6,0)||lpad(sc.NSUB,6,0)||lpad(sc.CLIENTE,10,0)||lpad(sc.FECAN,8,0)||lpad(sc.MOTIVO,1,0) cuentas_canceladas
from simgia_cccanceladas sc','N');
commit;
end;

-- Crea archivo de texto de asientos paginado
/*FUNCTION GEN_ASIENTOS_PAGINADO
  (p_archivo in varchar2,
   p_corte in number) return varchar2 is
   v_retorno varchar2(500);

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
v_filtro varchar2(250) := '';

begin

     --Se limpia la tabla temporal
      execute immediate 'truncate table mi_interfaz_asientos_tmp';
     --Se cargan los registros para la fecha actual
     insert into mi_interfaz_asientos_tmp (FECHA,TDIA,TSUC,TCTA,TBSUB,TTIPO,TCODOPE,TSER,TIMPORTE,TNUMDOC,TVALOR,TDIVISA,TIMPORDIV,TLINEA,TREF,TID)
     select FECHA,TDIA,TSUC,TCTA,TBSUB,TTIPO,TCODOPE,TSER,TIMPORTE,TNUMDOC,TVALOR,TDIVISA,TIMPORDIV,TLINEA,FU_SIM_NORM_CADENA(TREF,40), rownum
     from mi_interfaz_asientos t
     where t.fecha = to_char(pag_cal.fu_obt_fec_actual(3),'dd/mm/yyyy');
     -- descomentar la sigte linea para generar el archivo al dia anterior
     --where t.fecha = trunc(sysdate-1); de martes a viernes
     --where t.fecha = trunc(sysdate-3); los lunes

      -- se consulta cantidad de registros
      select count(*) into v_cant from mi_interfaz_asientos_tmp;
      --select count(*) into v_cant from mi_interfaz_asientos where fecha = '13/01/2010';
      --return  v_sql;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := p_archivo || '.TXT'; -- TO_CHAR(sysdate,'MMDD') ||'.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select
        tdia || CHR(59) || tsuc || CHR(59) || tcta || CHR(59) || tbsub || CHR(59) || ttipo || CHR(59) ||
        tcodope || CHR(59) || tser || CHR(59) || timporte || CHR(59) || tnumdoc || CHR(59) || tvalor || CHR(59) ||
        tdivisa || CHR(59) || timpordiv || CHR(59) || tlinea || CHR(59) || tref
        from mi_interfaz_asientos_tmp where tid between ' || v_ini || ' and ' || v_fin || ' order by tid asc '  ;

        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;
if v_cont2 > 0 then
   v_retorno := 'creado archivo ' || V_NOM || ' en ' || v_cont2 || ' paginas ';--v_paginas;
else
   v_retorno := null;
end if;

return v_retorno;
end;
*/





FUNCTION GEN_ASIENTOS_PAGINADO
  (p_archivo in varchar2,
   p_corte in number) return varchar2 is
   v_retorno varchar2(500);

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
--v_filtro varchar2(250) := '';
v_view varchar2(500) :='CREATE table mi_interfaz_asientos_tmpj as 
select FECHA,TDIA,TSUC,TCTA,TBSUB,TTIPO,TCODOPE,TSER,TIMPORTE,TNUMDOC,TVALOR,TDIVISA,TIMPORDIV,TLINEA,PAI_INT.FU_SIM_NORM_CADENA(TREF,40) TREF, TUSU,rownum TID
     from mi_interfaz_asientosj t
     where t.fecha = to_char(pag_cal.fu_obt_fec_actual(3),''dd/mm/yyyy'')';

begin

     --Se limpia la tabla temporal
     execute immediate 'drop table mi_interfaz_asientos_tmpj';
     --Se cargan los registros para la fecha actual
     execute immediate v_view;
         
   
     -- descomentar la sigte linea para generar el archivo al dia anterior
     --where t.fecha = trunc(sysdate-1); de martes a viernes
     --where t.fecha = trunc(sysdate-3); los lunes

      -- se consulta cantidad de registros
      select count(*) into v_cant from mi_interfaz_asientos_tmpj;
      --select count(*) into v_cant from mi_interfaz_asientos where fecha = '13/01/2010';
      --return  v_sql;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := p_archivo || '.TXT'; -- TO_CHAR(sysdate,'MMDD') ||'.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select
        tdia || CHR(59) || tsuc || CHR(59) || tcta || CHR(59) || tbsub || CHR(59) || ttipo || CHR(59) ||
        tcodope || CHR(59) || tser || CHR(59) || timporte || CHR(59) || tnumdoc || CHR(59) || tvalor || CHR(59) ||
        tdivisa || CHR(59) || timpordiv || CHR(59) || tlinea || CHR(59) || tref || CHR(59) || tusu
        from mi_interfaz_asientos_tmpj where tid between ' || v_ini || ' and ' || v_fin || ' order by tid asc '  ;

        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;
if v_cont2 > 0 then
   v_retorno := 'creado archivo ' || V_NOM || ' en ' || v_cont2 || ' paginas ';--v_paginas;
else
   v_retorno := null;
end if;

return v_retorno;
end;







-- Devuelve arclinomi en una tabla temporal by Juan Bauer
/*FUNCTION obtieneArclinomi RETURN myTableArclinomiType PIPELINED IS
       BEGIN
          declare
                  v_cod_persona varchar2(10);
                  v_val_parametro varchar2(200);
                  v_cant number;
                  v_pos number;
                  v_val varchar2(1);
                  v_parametro VARCHAR(10);
                  cursor arclinomi is
                  select  bpda.cod_persona, bpda.val_parametro
                  from  ba_per_dat_adicionales bpda
                  where bpda.parametro like 'EMP_VINCULADAS';
                  begin
                        open arclinomi;
                        loop
                        fetch arclinomi into v_cod_persona, v_val_parametro;
                        exit when arclinomi%notfound;

                        v_cant := length(v_val_parametro) + 1;
                          FOR v_pos IN 1..v_cant
                          LOOP

                           v_val := substr(v_val_parametro,v_pos,1);
                          if (v_val like ',') or (v_pos = v_cant)  then
                           PIPE ROW (myObjectArclinomiType(v_cod_persona, trim(v_parametro)));
                           v_parametro := null;
                          else
                           v_parametro := v_parametro || v_val;
                          end if;
                          END LOOP;
                        end loop;
                  end;
          RETURN;
       END;*/ --comentado el 2010-08-13 NAN.

/* ejecuta comandos de sistema */
/* ejecuta comandos de sistema */
PROCEDURE system_run(cmd IN varchar2, nom_proc IN varchar2 default 'PRG_SIMGIA')
IS
 vprogram varchar2(100);
 nprogram varchar2(100); -- := 'simgia_migra4';
BEGIN
  nprogram := nom_proc;
  begin
      SELECT program_name into vprogram FROM all_scheduler_programs where UPPER(program_name) = UPPER(nprogram);
  exception
      when no_data_found then
         vprogram := null;
  end;

  if vprogram is not null then
       DBMS_SCHEDULER.drop_program (program_name => vprogram);
  end if;

  --/*  -- Shell Script.
  DBMS_SCHEDULER.create_program (
    program_name        => nprogram,
    program_type        => 'EXECUTABLE',
    program_action      => cmd,
    number_of_arguments => 0,
    enabled             => TRUE,
    comments            => 'Ejecuta commandos del sistema');


  DBMS_SCHEDULER.enable (name => nprogram);
 --*/
END;

--sleep , fuerza tiempo de espera en segundos
FUNCTION smg_sleep(v_sec IN VARCHAR2 default 0) return timestamp
as
    v_time_end timestamp;
    v_time_now timestamp;
    v_sql varchar2(100):='';
BEGIN
    v_sql:='select (sysdate + interval '||chr(39)||v_sec||chr(39)||' second) from dual';
    execute immediate v_sql into v_time_end;
    select sysdate into v_time_now from dual;
    WHILE v_time_end >= v_time_now LOOP
        select sysdate into v_time_now from dual;
        --DBMS_OUTPUT.PUT_LINE('The value of c is ' || c);
    END LOOP;

    return(sysdate);
END;

-- bloqueos y desbloqueos
procedure migra_bloqueos is
begin
  pai_int.system_run('/orabkp/Testmigra4/migra.sh');
end;

-- Migracion de Inicio y fin de dia
--Migra ardeupend debcreit
procedure migrar_interfaz4 is
v_date date;
begin
  --borra la bandera de migracion terminada existente
  delete from SIMGIA_PROCESOS where nom_proceso = 'INTERFAZ4';
  prg_gen_archivo_txt('migra4.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
  v_date :=  pai_int.smg_sleep('50');
end;
/*--Migra Debcreit
procedure migrar_interfaz4b is
--v_date date;
begin
  prg_gen_archivo_txt('migra4b.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
  --v_date :=  pai_int.smg_sleep('60');
end;*/

-- Migracion de final del dia
procedure migrar_interfaz5 is
begin
  prg_gen_archivo_txt('migra5.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
  prg_gen_archivo_txt('migra5b.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
end;

-- Migracion de Armamay
procedure migrar_interfaz7 is
v_date date;
v_result number:=0;
v_fec_contable varchar2(10):=to_char(pae_cnf.fu_obt_fec_actual(2),'dd/mm/yy');
begin
  --trunca tabla armamay
  execute immediate 'truncate table simgia_armamay';
  --llama al migrador
  prg_gen_archivo_txt('migra7.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
  --se espera 2,5 min a que termine la migración
  v_date :=  pai_int.smg_sleep('160');
  -- se controla que la fecha del armamay coincida con la fecha del modulo contable
  select count(*) into v_result from simgia_armamay t where msuc = 0 and mcta = 0 and msubcta = 0 and fum = to_number(nvl(to_char(pae_cnf.fu_obt_fec_actual(2),'ddmmyy'),0)); 
  if(v_result=0) then
    --error, no son datos del dia actual
    RAISE_APPLICATION_ERROR(-20000,'Los datos de ARMAMAY no corresponden al día ' ||  v_fec_contable);
  end if;
end;

-- Backup vistas AS400
procedure backup_vistas is
v_date date;
v_error integer;
v_error_texto varchar2(250);

begin

   v_date := pag_cal.fu_obt_fec_actual(1);
   v_error := 0;
   v_error_texto := '';
  
   -- FASE 2
   execute immediate 'truncate table SIMGIA_OLFMAECDA_bkp';   
   execute immediate 'truncate table SIMGIA_AFDMAE_bkp';
   execute immediate 'truncate table SIMGIA_ARGYTAP_bkp';   
   execute immediate 'truncate table SIMGIA_ARVALPYP_bkp';  
   execute immediate 'truncate table SIMGIA_ARBOSUBTN_bkp';   
   execute immediate 'truncate table SIMGIA_ARDEPIGN_bkp';
   execute immediate 'truncate table SIMGIA_ARBOSUBOR_bkp';
   --delete from SIMGIA_OLFITOK_bkp;
   /*execute immediate 'truncate table SIMGIA_PREFMAE_bkp'; na 20110107*/
   /*execute immediate 'truncate table SIMGIA_ARCOLPLFM_bkp'; na 20110107*/
   /*execute immediate 'truncate table SIMGIA_ARTRNSFC_bkp'; na 20110107*/
   /*execute immediate 'truncate table SIMGIA_ARCTASEMB_bkp'; na 20110107*/
   /*execute immediate 'truncate table SIMGIA_CDABLQ_bkp'; na 20110107*/ 
   /*execute immediate 'truncate table SIMGIA_TRNCMBPRE_bkp'; na 20110107*/
   /*execute immediate 'truncate table Simgia_Maecartera_bkp'; na 20110107*/
   /*execute immediate 'truncate table Simgia_Maeicpc_bkp'; na 20110107*/
   
   begin
       insert into SIMGIA_OLFMAECDA_bkp select a.*, v_date from SIMGIA_OLFMAECDA a; 
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_OLFMAECDA ';  
   end;
   begin
       insert into SIMGIA_AFDMAE_bkp select a.*, v_date from SIMGIA_AFDMAE a; 
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_AFDMAE ';  
   end;
   begin
       insert into SIMGIA_ARVALPYP_bkp select a.*, v_date from SIMGIA_ARVALPYP a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_ARVALPYP ';  
   end;
  /* begin
       insert into SIMGIA_ARBOSUBTN_bkp select a.*, v_date from SIMGIA_ARBOSUBTN a; 
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_ARBOSUBTN ';  
   end;*/
   begin
       insert into SIMGIA_ARDEPIGN_bkp select a.*, v_date from SIMGIA_ARDEPIGN a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_ARDEPIGN ';  
   end;
   begin
       insert into SIMGIA_ARBOSUBOR_bkp select a.*, v_date from SIMGIA_ARBOSUBOR a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_ARBOSUBOR ';  
   end;
   /*
   begin
       insert into Simgia_Maecartera_bkp select a.*, v_date from Simgia_Maecartera a; 
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar Simgia_Maecartera ';  
   end;
   na 20110107*/
   /*
   begin
       insert into Simgia_Maeicpc_bkp select a.*, v_date from Simgia_Maeicpc a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar Simgia_Maeicpc ';  
   end;
   na 20110107*/
   --insert into SIMGIA_OLFITOK_bkp select a.*, v_date from SIMGIA_OLFITOK a;
   --insert into SIMGIA_ARGYTAP_bkp select a.*, v_date from SIMGIA_ARGYTAP a;
   --insert into SIMGIA_ARCOLPLFM_bkp select a.*, v_date from SIMGIA_ARCOLPLFM a;   
   --insert into SIMGIA_ARTRNSFC_bkp select a.*, v_date from SIMGIA_ARTRNSFC a;
   --insert into SIMGIA_ARCTASEMB_bkp select a.*, v_date from SIMGIA_ARCTASEMB a;   
   --insert into SIMGIA_CDABLQ_bkp select a.*, v_date from SIMGIA_CDABLQ a;   
   /*insert into SIMGIA_TRNCMBPRE_bkp select a.*, v_date from SIMGIA_TRNCMBPRE a; con autoriz de Vicor Palomar*/
   
   

   --FASE 3
   execute immediate 'truncate table simgia_arsobgc_bkp';
   execute immediate 'truncate table simgia_arma719_bkp';
   execute immediate 'truncate table simgia_arma711_bkp';
   execute immediate 'truncate table simgia_arma709_bkp';
   execute immediate 'truncate table simgia_arma700_bkp';
   execute immediate 'truncate table SIMGIA_ARDEPIGN_2_bkp';
   execute immediate 'truncate table SIMGIA_ARCHSOB_BKP';
   execute immediate 'truncate table SIMGIA_ARCHSOBME_BKP';
   
   /*execute immediate 'truncate table simgia_olfauxchqn_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_olfauxblq_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_olfauxanl_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_maegarante_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_hischqdev_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_cccanceladas_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_arpaquete_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_arley2835_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_arcobpend_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_arclinomi_bkp'; na 20110107*/
   /*execute immediate 'truncate table simgia_arcajaseg_bkp'; na 20110107*/
   
   /*
   begin
       insert into simgia_maegarante_bkp select a.*, v_date from simgia_maegarante a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_maegarante ';  
   end; na 20110107*/
   begin
       insert into simgia_arsobgc_bkp select a.*, v_date from simgia_arsobgc a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arsobgc ';  
   end;
   /*
   begin
       insert into simgia_arpaquete_bkp select a.*, v_date from simgia_arpaquete a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arpaquete ';  
   end; na 20110107*/
   begin
       insert into simgia_arma719_bkp select a.*, v_date from simgia_arma719 a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arma719 ';  
   end;
   begin
       insert into simgia_arma711_bkp select a.*, v_date from simgia_arma711 a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arma711 ';  
   end;
   begin
       insert into simgia_arma709_bkp select a.*, v_date from simgia_arma709 a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arma709 ';  
   end;
   begin
       insert into simgia_arma700_bkp select a.*, v_date from simgia_arma700 a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arma700 ';  
   end;
   begin
       insert into SIMGIA_ARDEPIGN_2_bkp select a.*, v_date from SIMGIA_ARDEPIGN_2 a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar SIMGIA_ARDEPIGN_2 ';  
   end;
    begin
       insert into SIMGIA_ARCHSOBME_BKP select a.*, v_date from simgia_arma709_sob a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arma709 ';  
   end;
   begin
       insert into SIMGIA_ARCHSOB_BKP select a.*, v_date from simgia_arma700_sob a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arma700 ';  
   end;
   /*begin
       insert into simgia_arcobpend_bkp select a.*, v_date from simgia_arcobpend a;
   exception
      when others then
         v_error := 1;
         v_error_texto := v_error_texto || 'Error al copiar simgia_arcobpend ';  
   end; na 20110107*/
   --insert into simgia_olfauxchqn_bkp select a.*, v_date from simgia_olfauxchqn a;
   --insert into simgia_olfauxblq_bkp select a.*, v_date from simgia_olfauxblq a;
   --insert into simgia_olfauxanl_bkp select a.*, v_date from simgia_olfauxanl a;   
   --insert into simgia_hischqdev_bkp select a.*, v_date from simgia_hischqdev a;
  -- insert into simgia_cccanceladas_bkp select a.*, v_date from simgia_cccanceladas a;
   --insert into simgia_arley2835_bkp select a.*, v_date from simgia_arley2835 a;
   --insert into simgia_arclinomi_bkp select a.*, v_date from simgia_arclinomi a;
   --insert into simgia_arcajaseg_bkp select a.*, v_date from simgia_arcajaseg a;

   --tablas IT para armas
  /* execute immediate 'truncate table simgia_tah_cta_vistas';
   insert into simgia_tah_cta_vistas select * from ah_cta_vistas;

   execute immediate 'truncate table simgia_tcc_lin_sobregiros';
   insert into simgia_tcc_lin_sobregiros select * from cc_lin_sobregiros;

   execute immediate 'truncate table simgia_tcc_cta_corrientes';
   insert into simgia_tcc_cta_corrientes select * from cc_cta_corrientes;

   execute immediate 'truncate table simgia_tcc_sobregiros';
   insert into simgia_tcc_sobregiros select * from cc_sobregiros;*/
   if v_error = 1 then
      RAISE_APPLICATION_ERROR(-20000,v_error_texto);
   end if;
end;

-- Backup tabla procesamiento debcreit
procedure bkp_debcreit is
begin
   insert into simgia_debcreit_bkp select * from simgia_debcreit a;
end;

-- reprocesar estado 9 de debcreit de fecha actual
procedure reproc_debcreit is
begin
   insert into simgia_debcreit select * from simgia_debcreit_bkp d where d.estado='9' and d.fec_proceso = pag_cal.FU_OBT_FEC_ACTUAL(1);
end;

-- Backup tabla procesamiento ardeupend
procedure bkp_ardeupend is
begin
   insert into simgia_ardeupend_bkp select * from simgia_ardeupend a;
end;

-- Verifica existencia de datos actualizados en simgia_debcreit
procedure PRG_DEBCREIT_ACTUALIZADO( RESPUESTA OUT VARCHAR2)
as
BEGIN
   --select nvl((select 'S' from simgia_debcreit d where d.fec_migracion > (sysdate - interval '360' MINUTE) and rownum = 1), 'N') into RESPUESTA
   --select nvl((select 'S' from simgia_debcreit d where d.fec_proceso = pag_cal.fu_obt_fec_actual(1)  and rownum = 1), 'N') into RESPUESTA from dual;
   RESPUESTA := 'S';
END;

-- Borra registros con fecha actual
procedure DEL_REG_DEBCREIT is
BEGIN
   delete from simgia_debcreit d where d.fec_proceso = pag_cal.fu_obt_fec_actual(1);
END;

-- actualiza montos de deudas pendientes en la AS400
PROCEDURE ACTUALIZAR_DEU_PEND is
cursor c_deuda_pendientes is
       select * from mi_deu_pendientes mdp order by nro_cuenta;
c_datos_deuda c_deuda_pendientes%rowtype;

         CURSOR c_ge_bloqueados IS SELECT * FROM ge_bloqueos ge WHERE ge.cod_causa=251;
         c_datos_cursor  c_ge_bloqueados%ROWTYPE;

         v_fec_actual date:=pag_cal.FU_OBT_FEC_ACTUAL(1);

--variales
v_hora ge_bloqueos.hor_inicio%TYPE:=to_char(SYSDATE,'HH24:MI:SS');

begin
  -- se limpia estado y respuesta de as400 de la mañana
  update simgia_ardeupend a set a.respuesta = null, a.est_proceso = null where a.fec_proceso = pag_cal.fu_obt_fec_actual(1);

  --se desbloquean cuentas de la mañana
   BEGIN
       OPEN c_ge_bloqueados;
       LOOP
       FETCH c_ge_bloqueados INTO c_datos_cursor;
           IF c_ge_bloqueados%FOUND THEN
                --obtencion cuentas y conf
                BEGIN
                    pag_cta.PR_OBT_CUENTA(c_datos_cursor.nro_cuenta);
                    if pag_cta.G_COD_ERROR <> 0 then
                       RAISE_APPLICATION_ERROR(-20000,'Error:'||pag_cta.G_MSJ_ERROR);
                    end if;
                    pag_cta.PR_ACT_SAL_CTA(
                                        c_datos_cursor.nro_cuenta,
                                        pag_cta.G_CTAS.cod_modalidad,
                                        'C',
                                        v_fec_actual,
                                        v_hora,
                                        0,
                                        0,
                                        c_datos_cursor.monto * -1,
                                        'N',
                                        'N');
                   IF pag_cta.G_COD_ERROR <> 0 THEN
                      RAISE_APPLICATION_ERROR(-20000,'Error:'||pag_cta.G_MSJ_ERROR);
                   END IF;
                   --eliminamos registro en la tabla ge_bloqueos
                   --pk->nro_cuenta,fec_inicio,nro_documento
                   DELETE FROM ge_bloqueos WHERE
                          nro_cuenta = c_datos_cursor.nro_cuenta
                          AND fec_inicio = c_datos_cursor.fec_inicio
                          AND nro_documento = c_datos_cursor.nro_documento;
               END;
           END IF;
       EXIT WHEN c_ge_bloqueados%NOTFOUND;
       END LOOP;
  EXCEPTION
  WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'Error:'||sqlerrm);
  END;

  --se recorre ardeupend de vuelta
  open c_deuda_pendientes;
    loop
      fetch c_deuda_pendientes into c_datos_deuda;
        if c_deuda_pendientes%found then
          begin
             PRG_BLO_DEU_PENDIENTES(c_datos_deuda.nro_cuenta,c_datos_deuda.mto_deuda,0);
          Exception
          when others then
             null;
          end;
          commit;
        end if;
      exit when c_deuda_pendientes%notfound;
    end loop;
  close c_deuda_pendientes;
exception
when others then
   update simgia_ardeupend set est_proceso = null, respuesta = null where nro_cuenta = c_datos_deuda.nro_cuenta;
   commit;
     RAISE_APPLICATION_ERROR(-20000,'Error:'||c_datos_deuda.nro_cuenta||'  '||c_datos_deuda.mto_deuda||' '||sqlerrm);
end;

-- Actualiza cb_sal_oficina desde vista (simgia_aldo_oficina) de armamay
procedure actualiza_sal_ofi is
v_result number:=0;
v_fec_contable varchar2(10):=to_char(pae_cnf.fu_obt_fec_actual(2),'dd/mm/yy');
begin
    --se borran los datos de la tabla
    delete from cb_sal_oficinas;
    
    -- se controla si los datos corresponden a la fecha del modulo contable
    select count(*) into v_result from simgia_armamay t where msuc = 0 and mcta = 0 and msubcta = 0 and fum = to_number(nvl(to_char(pae_cnf.fu_obt_fec_actual(2),'ddmmyy'),0));
    
    if(v_result=0) then
      --error, no son datos del dia actual
      RAISE_APPLICATION_ERROR(-20000,'Los datos de ARMAMAY no corresponden al día ' ||  v_fec_contable);
    else
      -- se cargan los datos migrados
      insert into cb_sal_oficinas
      (COD_OFICINA,
      COD_RUBRO,
      ANO,
      MES,
      SAL_MON_LOC_ANT,
      DEB_MON_LOCAL,
      CRE_MON_LOCAL,
      SAL_INI_MES_MON_LOCAL,
      SAL_MON_RUB_ANT,
      DEB_MON_RUBRO,
      CRE_MON_RUBRO,
      SAL_INI_MES_MON_RUBRO,
      SAL_INI_MES_MON_FUERTE,
      PROTEGIDO,
      SAL_EQU_LOC_ANT,
      DEB_EQU_LOCAL,
      CRE_EQU_LOCAL,
      SAL_INI_MES_EQU_LOCAL)
      select COD_OFICINA,
      COD_RUBRO,
      ANO,
      MES,
      SAL_MON_LOC_ANT,
      DEB_MON_LOCAL,
      CRE_MON_LOCAL,
      SAL_INI_MES_MON_LOCAL,
      SAL_MON_RUB_ANT,
      DEB_MON_RUBRO,
      CRE_MON_RUBRO,
      SAL_INI_MES_MON_RUBRO,
      SAL_INI_MES_MON_FUERTE,
      PROTEGIDO,
      SAL_EQU_LOC_ANT,
      DEB_EQU_LOCAL,
      CRE_EQU_LOCAL,
      SAL_INI_MES_EQU_LOCAL
      from simgia_saldo_oficina;
    end if;
end;

PROCEDURE ctrl_proc(proceso IN varchar2) is
vresult number(1);
vresult2 number(1);
begin
-- verifica si existe
select count(*) into vresult from SIMGIA_PROCESOS where nom_proceso = proceso;
if(vresult > 0) then
    -- si existe, verifica si ya se corrio
    select count(*) into vresult2 from SIMGIA_PROCESOS where nom_proceso = proceso and fec_proceso = pag_cal.fu_obt_fec_actual(1);
    if(vresult2 > 0) then
       RAISE_APPLICATION_ERROR(-20000,'YA SE HA EJECUTADO ESTE PROCESO "'|| proceso || '" EL DÍA DE HOY.');
    else
    --todavia no se ejecuto hoy
       update SIMGIA_PROCESOS set fec_proceso = pag_cal.fu_obt_fec_actual(1) where nom_proceso = proceso;
    end if;
else
    -- no existe, se inserta el proceso
   insert into SIMGIA_PROCESOS (nom_proceso,Fec_Proceso) values(proceso,pag_cal.fu_obt_fec_actual(1));
end if;
end;

--Controla que proceso independiente de debcreit se ejecute solo una vez al dia
procedure ctrl_debcreit is
begin
    ctrl_proc('DEBCREIT');
end;

--Controla que proceso independiente de ardeupend se ejecute solo una vez al dia
procedure ctrl_ardeupend is
begin
    ctrl_proc('ARDEUPEND');
end;

--Controla que proceso independiente de armamay se ejecute solo una vez al dia
procedure ctrl_armamay is
begin
    --ctrl_proc('ARMAMAY');
    --ctrl_proc_fec_mod('ARMAMAY', 2);--2010/06/02 controla por fecha de modulo, a pedido de Ingrid
    ctrl_armamay_fec_mod; -- 20100920 permite ejecutar mas de una vez al dia a pedido de Hector B.
end;

--Controla Termino de migración
function ctrl_migra(proceso IN varchar2) return number
is
vresult number(1);
begin
  -- verifica si existe con fecha actual del sistema
  select count(*) into vresult from SIMGIA_PROCESOS where nom_proceso = proceso and fec_proceso = pag_cal.fu_obt_fec_actual(1);
  if(vresult > 0) then
    RETURN 1;
  else
     RETURN 0;
  end if;
end;

--Controla que la migracion de Interfaz4 halla concluido para continuar acon sigte proceso
--Se utiliza entra procesos independientes, crea un delay por el tiempo que sea necesario
procedure ctrl_interfaz4 is
vcont number;
vresult number;
vdate date;
begin
    --se consulta estado de la migracion
    --0 aun no termina
    --1 terminada
    vcont := 0;
    select ctrl_migra('INTERFAZ4') into vresult from dual;
    WHILE vresult = 0 LOOP
        --delay de 60 segs
        vdate :=  pai_int.smg_sleep('30');
        --consulta estado de la migracion
        select ctrl_migra('INTERFAZ4') into vresult from dual;
        vcont := vcont + 1;
        if(vcont > 19) then
             RAISE_APPLICATION_ERROR(-20000,'Interfaz4 esta tardando mas de 10min. Controlar logs de la migracion.');
        end if;
    END LOOP;
end;

--Devuelve fecha de venciumiento de ultima cuota exportacion
function exp_fec_ult_cuota(vcuenta IN varchar2) return date
is
vresult date;
begin
  vresult := null;
  select c.fec_vencimiento into vresult
  from cx_cuotas c
  where c.nro_cuenta = vcuenta and rownum = 1 order by c.nro_cuota desc;

  RETURN vresult;

end;

-- Controla ejecucion de procesos de simgia, por fecha de modulo
PROCEDURE ctrl_proc_fec_mod(proceso IN varchar2, vmodulo IN number) is
vresult number(1);
vresult2 number(1);
begin
-- verifica si existe
select count(*) into vresult from SIMGIA_PROCESOS where nom_proceso = proceso;
if(vresult > 0) then
    -- si existe, verifica si ya se corrio
    select count(*) into vresult2 from SIMGIA_PROCESOS where nom_proceso = proceso and fec_proceso = pag_cal.fu_obt_fec_actual(vmodulo);
    if(vresult2 > 0) then
       RAISE_APPLICATION_ERROR(-20000,'YA SE HA EJECUTADO ESTE PROCESO "'|| proceso || '" EL DÍA DE HOY.');
    else
    --todavia no se ejecuto hoy
       update SIMGIA_PROCESOS set fec_proceso = pag_cal.fu_obt_fec_actual(vmodulo) where nom_proceso = proceso;
    end if;
else
    -- no existe, se inserta el proceso
   insert into SIMGIA_PROCESOS (nom_proceso,Fec_Proceso) values(proceso,pag_cal.fu_obt_fec_actual(vmodulo));
end if;
end;

-- Controla ejecucion de Armamay v2010-09-20
PROCEDURE ctrl_armamay_fec_mod is
vresult number;
vresult2 number;
vresult3 number;
vproceso varchar2(100);
vmodulo number;
vfecha2 date;
vmodhab number;
begin
vproceso := 'ARMAMAY';
-- verifica si existe
select count(*) into vresult from SIMGIA_PROCESOS where nom_proceso = vproceso;
if(vresult > 0) then
    -- se consulta fecha anterior, se usa como referencia el modulo 1
    -- OBS: los datos de armamay estan siempre a fecha anterior
    vmodhab :=  mod_habilitado(1);
    if(pag_cal.fu_obt_fec_actual(1) < trunc(sysdate) and vmodhab=0) then
        -- cuando se procesa en bbvatest, se utiliza la fecha actual
        vfecha2 := pag_cal.fu_obt_fec_actual(1);
    else        
        -- cuando se procesa en producción, se procesa al dia anterior
        select b.fec_anterior into vfecha2 from ge_calendarios b where cod_modulo = 1 and rownum=1;       
    end if;
    -- se consulta en simgia procesos si ya corrio el dia de hoy
    -- si existe, verifica si ya se corrio
    select count(*) into vresult2 from SIMGIA_PROCESOS where nom_proceso = vproceso and fec_proceso = pag_cal.fu_obt_fec_actual(1);
    select count(*) into vresult3 from cb_sal_oficinas_dia where fecha = vfecha2;
    
    --modulo contable: se adecua la fecha antes de procesar
    update ge_calendarios set fec_actual = vfecha2 where cod_modulo = 2;
    
    if(vresult2 > 0 or vresult3 > 0) then              
       --se borran datos anteriores del dia de las tablas contables en ITGF
       delete cb_sal_oficinas;
       delete cb_sal_consolidados;       
       delete cb_sal_oficinas_dia where fecha = vfecha2;       
       delete cb_sal_consolidados_dia where fecha = vfecha2;
       delete sb_encajes_ml where fecha = vfecha2;
       delete sb_encajes_me where fecha = vfecha2;
       delete sb_encajes_det where fecha = vfecha2;   
    end if;
    update SIMGIA_PROCESOS set fec_proceso = pag_cal.fu_obt_fec_actual(1) where nom_proceso = vproceso;  
else
    -- no existe, se inserta el proceso como ejecutado
   insert into SIMGIA_PROCESOS (nom_proceso,Fec_Proceso) values(vproceso,pag_cal.fu_obt_fec_actual(1));   
end if;
end;

--Actualiza fecha de modulo contable, en caso de existir apertura de día
procedure PRB_ACT_CALENDARIO is
vfecha date;
begin
    vfecha := pag_cal.fu_obt_fec_actual(1);
    --- Cambiar fecha del modulo CONTABLE
    --- Deja preparado para procesamiento de mañana
    update ge_calendarios
    set fec_actual = vfecha
    where cod_modulo = 2;
    
end;

function mod_habilitado(vmodulo IN number) return number is
v_est_proceso number;
begin
   select estado
   into v_est_proceso
   from ba_modulos
   where cod_modulo = vmodulo;
   
   -- El primer modulo es el que contiene al modulo base

   if nvl(v_est_proceso,2) <> 2 and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
      return 0;
   end if;
   return 1;
end;

--Extrae el usuario que cargo el asiento contable
function extrae_usuario_asiento(v_fecha IN date, v_nro_doc IN number) return varchar2 is
v_cod_usuario varchar2(50);
begin
            
  select m.cod_usuario into v_cod_usuario 
  from ge_movimientos m
  where m.fecha = v_fecha
  and m.nro_documento4 = v_nro_doc;

    
  return v_cod_usuario;
  
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
         return 'VARIOS';
    when no_data_found then
         return 'VACIO';
    WHEN OTHERS THEN
         return 'ERROR';
end;

-- calculo de saldo de ctas corriente con lógica del inventario
-- para migración de ARMA700, ARMA709, ARMA711, ARMA719
function calcula_saldo_arma7xx(v_sal_tot_batch IN number,v_sal_ret_batch IN number,v_sal_blo_batch IN number) return number is
v_sal_disponible number;
v_sal_contable number;
begin
v_sal_disponible := v_sal_tot_batch - v_sal_ret_batch - v_sal_blo_batch;

     CASE
        WHEN v_sal_disponible > 0 and v_sal_blo_batch = 0 THEN
           v_sal_contable := v_sal_disponible;
        WHEN v_sal_disponible > 0 and v_sal_blo_batch > 0 THEN
           v_sal_contable := v_sal_disponible + v_sal_blo_batch;
        WHEN v_sal_disponible < 0 and v_sal_blo_batch > 0 THEN
           v_sal_contable := v_sal_blo_batch;
        WHEN v_sal_disponible = 0 and v_sal_blo_batch > 0 THEN
           v_sal_contable := v_sal_blo_batch;
        WHEN v_sal_disponible < 0 and v_sal_blo_batch = 0 THEN
           v_sal_contable := 0;
        WHEN v_sal_disponible = 0 and v_sal_blo_batch = 0 THEN
           v_sal_contable := 0; --confirmar!!!
        ELSE
           v_sal_contable := 0; --OBS: hubo un error con una cuenta que tenía sal_blo_batch negativo
           --RAISE_APPLICATION_ERROR(-20000,'CTA: '||v_nro_cuenta||'. ERROR EN ACU_CTACTE_NORMAL:' || sqlerrm);
     END CASE;

     return v_sal_contable;
end;

-- obtiene sobregiros de ARMA700 y ARMA709
function obt_rub_sobregiro(
v_cod_modulo in ge_cuentas.cod_modulo%type,
v_cod_modalidad in ge_cuentas.cod_modalidad%type,
v_cod_moneda in ge_cuentas.cod_moneda%type,
v_cod_persona VARCHAR2,
v_nro_cuenta VARCHAR2,
v_sal_tot_batch NUMBER ) return varchar2 is
v_sit_deuda varchar2(50);
v_cod_rubro VARCHAR2(15);
v_mto_lin_sobregiro NUMBER(22,2);
v_sob_con_acuerdo    NUMBER(22,2);
v_sob_sin_acuerdo    NUMBER(22,2);

begin

  begin
    select r.sit_deuda into v_sit_deuda
    from cc_sobregiros_res r
    where r.nro_cuenta=v_nro_cuenta;
  exception
    when no_data_found then
       v_sit_deuda := 'S';
    when others then
       --v_sit_deuda := null;
       raise_application_error(-20000,'ERROR al obtener SIT_DEUDA en obt_tra_sobregiro. Nro_cuenta: '||v_nro_cuenta||'. :'|| sqlerrm);
  end;

  v_cod_rubro := NULL;
  
   case
     when v_sit_deuda='V' then --Vencido
        v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,949,v_cod_moneda,v_cod_persona,'1','D');
        if(v_cod_rubro is null) then
           v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,909,v_cod_moneda,v_cod_persona,'1','D');
        end if;

     when v_sit_deuda='G' then --Gestion
        v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,940,v_cod_moneda,v_cod_persona,'1','D');
        if(v_cod_rubro is null) then
           v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,900,v_cod_moneda,v_cod_persona,'1','D');
        end if;

     when v_sit_deuda in ('M','I') then --Moroso
        v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,912,v_cod_moneda,v_cod_persona,'1','D');
        if(v_cod_rubro is null) then
           v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,952,v_cod_moneda,v_cod_persona,'1','D');
        end if;

     when v_sit_deuda='S' then --Transitorio o Autorizado
        v_mto_lin_sobregiro := fuc_obt_mto_lin_sob(v_nro_cuenta,'T');

        v_sob_con_acuerdo := 0;
        v_sob_sin_acuerdo := 0;

        if(nvl(v_mto_lin_sobregiro,0) >= abs(v_sal_tot_batch)) then
           v_sob_con_acuerdo := abs(v_sal_tot_batch);
           v_sob_sin_acuerdo := 0;
        elsif(nvl(v_mto_lin_sobregiro,0) > 0 and nvl(v_mto_lin_sobregiro,0) < abs(v_sal_tot_batch)) then
           v_sob_con_acuerdo := v_mto_lin_sobregiro;
           v_sob_sin_acuerdo := abs(v_sal_tot_batch) - v_mto_lin_sobregiro;
        else
           v_sob_con_acuerdo := 0;
           v_sob_sin_acuerdo := abs(v_sal_tot_batch);
        end if;
        
        IF(v_sob_sin_acuerdo>0) THEN
          --Transitorio
          v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,902,v_cod_moneda,v_cod_persona,'1','D');
        ELSIF(v_sob_con_acuerdo>0) THEN
          --Autorizado
          v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo,v_cod_modalidad,942,v_cod_moneda,v_cod_persona,'1','D');
        ELSE
          v_cod_rubro := 0;
        End if;
   end case;
   
  
   RETURN PAI_INT.fu_obt_cta_contable(v_cod_rubro);
   --RETURN v_cod_rubro;
  
 end;
end PAI_INT;
/

