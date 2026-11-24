CREATE OR REPLACE PACKAGE BODY IT.PAI_INT_F4 is
-- OBTIENE LA FECHA DE INICIO DE MD_DOC_DETALLES
FUNCTION FU_SIM_OBT_FECHAINI_PR_CUOTA(vnro_documento varchar2, vnro_cuota number) return date is
  vfecha      date := null;
begin

     If vnro_cuota = 1 then

      select min(fec_inicio) into vfecha
      from pr_devengados
      where nro_cuenta = vnro_documento;


     else
          select fec_vencimiento  into vfecha
          from pr_cuotas
          where nro_cuenta = vnro_documento
          and nro_cuota= vnro_cuota - 1;

     end if;

     if vfecha is null then
            select p.fec_inicio into vfecha
            from pr_cta_prestamos p
            where p.nro_cuenta = vnro_documento;
            return (vfecha);
     end if;

   return(vfecha);
   Exception
  when no_data_found then
      /*select min(fec_inicio) into vfecha
      from pr_devengados
      where nro_cuenta = vnro_documento;
      return (vfecha);*/
      select p.fec_inicio into vfecha
      from pr_cta_prestamos p
      where p.nro_cuenta = vnro_documento;
      return (vfecha);

end;

--OBTIENE EL MONTO MONTO_DEVENGADO POR MEDIO DEL NRO DE CUENTA Y LA FECHA DE INICIO DE LA CUOTA
function FU_SIM_OBT_MTO_PR_CUOTA(vnro_cuenta  varchar2, vfecha_inicio  date) return number is
  vmonto number(15,2);
begin

  select mto_dev_acumulado into vmonto
  from pr_devengados
  where nro_cuenta = vnro_cuenta
  and fec_inicio = vfecha_inicio;


  return(vmonto);
end;

--Obtiene la Cuenta Contable
FUNCTION FU_OBT_CTA_CONTABLE_PR_CUOTA
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

--obtiene cuenta contable intereses en suspenso
FUNCTION FU_OBT_CTA_INT_SUSPENSO
(P_RUBRO VARCHAR2, P_MONEDA NUMBER)
return varchar2
is
v_cuenta varchar2(20);
v_moneda number;
p_plazo number;
begin
if  P_MONEDA = 0 then
    v_moneda := 101;
else
    v_moneda := 102;
end if;
p_plazo := substr(P_RUBRO, 4, 1);

v_cuenta := 225||p_plazo||9200||v_moneda;

case
when v_cuenta = '22519200101' then
     v_cuenta := v_cuenta||4;
when v_cuenta = '22519200102' then
     v_cuenta := v_cuenta||2;
when v_cuenta = '22529200101' then
     v_cuenta := v_cuenta||5;
when v_cuenta = '22529200102' then
     v_cuenta := v_cuenta||3;
when v_cuenta = '22539200101' then
     v_cuenta := v_cuenta||6;
when v_cuenta = '22539200102' then
     v_cuenta := v_cuenta||4;
when v_cuenta = '22549200101' then
     v_cuenta := v_cuenta||7;
when v_cuenta = '22549200102' then
     v_cuenta := v_cuenta||5;
when v_cuenta = '22559200101' then
     v_cuenta := v_cuenta||8;
when v_cuenta = '22559200102' then
     v_cuenta := v_cuenta||6;
when v_cuenta = '22569200101' then
     v_cuenta := v_cuenta||9;
when v_cuenta = '22569200102' then
     v_cuenta := v_cuenta||7;
when v_cuenta = '22579200101' then
     v_cuenta := v_cuenta||0;
when v_cuenta = '22579200102' then
     v_cuenta := v_cuenta||8;
when v_cuenta = '22589200101' then
     v_cuenta := v_cuenta||1;
when v_cuenta = '22589200102' then
     v_cuenta := v_cuenta||9;
else
     v_cuenta := 999;
end case;
return v_cuenta;
end;

-- Backup vistas AS400
procedure backup_vistas is
v_date date;
begin

   v_date := pag_cal.fu_obt_fec_actual(6);

   -- FASE 4
   execute immediate 'truncate table simgia_propuemae_bkp';
   execute immediate 'truncate table SIMGIA_MAECARTERA_F4_bkp';
   execute immediate 'truncate table Simgia_Maeicpc_f4_bkp';
   execute immediate 'truncate table smg_maecartera_file';
   execute immediate 'truncate table simgia_arpagtcit_bkp';
   execute immediate 'truncate table simgia_maerindir_bkp';
   execute immediate 'truncate table simgia_archcerti_bkp';
   execute immediate 'truncate table simgia_cp';
   execute immediate 'truncate table simgia_cr';
   
    
   insert into simgia_propuemae_bkp select a.*, v_date from simgia_propuemae a;
   insert into Simgia_Maecartera_f4_bkp(FECHA,SUCURSALFU,NURIES,PROPUESTA,CONGRU,NUDOC,GUARANIES,CONTRAVALO,IADDIVISA,VENCIM,CODTASA,NROLIBRADO,CTADOCACT,RUBRO_ACT,CTADOCPAS,RUBRO_PAS,FILLER,TIPOD,FECHAEMISI,SUCURSALCU,GASTOSGC,VCTOINT,IADMONTODC,IADSALDOCP,IADMETODO,IADFEINI,IADDIAS,IADINTERES,IADADEV,IADNROCUO,IADCODTASA,CTANDOCACT,CTANDOCORD,CTANDOCORH,RUBRO,TRANSACCION,TRANSACCION2,TRANSACCION3,MODALIDAD,TIP_AMORTIZACION,COD_MONEDA,CAT_RIESGO,NRO_CUENTA,COD_ORI_FONDO,TIPO,RUBRO_SUSP,FECHA_HIS) select a.*, v_date from Simgia_Maecartera_f4 a;
   insert into Simgia_Maeicpc_f4_bkp(RIESGO,VTO,DOCNRO,SUCURSAL,INTERES,FEINI,INTDEV,INTNODEV,FECHCONT,PERIODO,MODALIDAD,COD_MODULO,FEECHA,COD_PERSONA,COD_SEC_CREDITO,TIP_INTERES,TIP_RENOVACION,TRANSACCION,RUBROCR,RUBROCR_RUB_IT,INDDOCUM,TRANSACCION2,CTAACTIVO,CTAACTIVO_RUB_IT,CTAORDACT,TRANSACCION3,CTAPASIVO,CTAPASIVO_RUB_IT,COBADL,PROPUESTA,ESTADO,INDPAGO,SERVICIO,FILLER,DEVSUSP,NRO_CUENTA,COD_MODALIDAD,COD_SIT_CONTABLE,ESTADO_IT,ESTADO_DET,SAL_INTERES,SAL_INT_DOCUMENTADO,MTO_INTERES,DEV_ACUMULADO,NRO_CUOTA,COD_MONEDA,RUBRO_SUSP,FECHA_HIS) select a.*, v_date --pag_cal.fu_obt_fec_actual(6) 
     from Simgia_Maeicpc_f4 a;
   --insert into smg_maecartera_file select rownum id, t.* from simgia_maecartera_f4_file t;
   insert into simgia_arpagtcit_bkp(RPFCHA,RPHORA,RPUSR,RPCTA,RPMONE,RPMONTO,RPSUC,RPORI,RPCONC,RPCAJA,RPRUBIT,RPRUBAS,RPTIPO,RPTRN,RPMOD,RPTRNP,RPASIE,RPLINE,REVERSADO,FECHA_HIS) select a.*, v_date from simgia_arpagtcit a;
   insert into simgia_maerindir_bkp select a.*, v_date from simgia_maerindir a;
   insert into simgia_archcerti_bkp select a.*, v_date from simgia_archcerti a;
    
   insert into simgia_cp (COD_PERSONA,COD_OFICINA,NOM_PERSONA,MONTO_GS,NOM_GESTOR,FECHA,cod_gestor) 
   select a.cod_persona, a.cod_oficina, a.nom_completo, a.monto_gs, a.nom_gestor, a.fecha, a.cod_gestor
   from simgia_genera_cp a where a.fecha = v_date; --(select b.fec_actual from ge_calendarios b where b.cod_modulo = 1);

   insert into simgia_cr (COD_PERSONA,COD_OFICINA,NOM_PERSONA,MONTO_GS,NOM_GESTOR,FECHA,cod_gestor) 
   select a.cod_persona, a.cod_oficina, a.nom_completo, a.monto_gs, a.nom_gestor, a.fecha, a.cod_gestor
   from simgia_genera_cr a where a.fecha = v_date; --(select b.fec_actual from ge_calendarios b where b.cod_modulo = 1);

end;

-- Crea archivo de texto de MAECARTERA
procedure GEN_MAECARTERA_PAG is

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
p_corte number:= 9000;

begin

      -- se consulta cantidad de registros
      --select count(*) into v_cant from smg_maecartera_file;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'MAECARTERA.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select linea from smg_maecartera_file where ID <= ' || v_fin || ' and ID >= ' || v_ini ;


        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;

end;

-- Crea archivo de texto de MAEICPC
procedure GEN_MAEICPC_PAG is

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
p_corte number:= 9000;

begin

      -- se consulta cantidad de registros
      select count(*) into v_cant from simgia_maeicpc_f4_file;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'MAEICPC.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP


        V_SQL := 'select linea
        from
        ( select a.*, rownum rnum
        from ( select * from simgia_maeicpc_f4_file order by linea asc ) a
        where rownum <= ' || v_fin || ' )
        where rnum >= ' || v_ini ;


        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;

end;

function OBT_COD_AVAL (vnro_cuenta varchar2, vid number)
return varchar2
is
vcod_persona varchar2(10);
begin
   select g.nro_garantia into vcod_persona from
  (select rownum id, t.*
  from pr_cta_garantias t
  where t.cod_garantia = 2
  and t.nro_cuenta = vnro_cuenta) g
  where g.id = vid;

  return nvl(vcod_persona,0);
end;

-- Crea archivo de texto de GARANTIAS
procedure GEN_GARANIT_PAG is

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
p_corte number:= 9000;

begin

      -- se consulta cantidad de registros
      select count(*) into v_cant from smg_iv_garantias;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'GARANIT_'||TO_CHAR(pag_cal.fu_obt_fec_actual(1),'YYMMDD')||'.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP


        V_SQL := 'select novtipo || CHR(59) || clien || CHR(59) || modal || CHR(59) ||
         nro || CHR(59) || suc || CHR(59) || cuenta || CHR(59) || fchcont || CHR(59) ||
          fchvcont || CHR(59) || divi || CHR(59) || monto || CHR(59) || tasacion ||
          CHR(59) || exceso || CHR(59) || operador || CHR(59) || fchtasac || CHR(59) ||
          nroescri || CHR(59) || escribano || CHR(59) || descrip || CHR(59) || estado ||
          CHR(59) || desc_estado
        from
        ( select a.*, rownum rnum
        from ( select *
               from smg_iv_garantias ) a
        where rownum <= ' || v_fin || ' )
        where rnum >= ' || v_ini ;


        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;

end;

--Retorna monto de reisgo para informe inventario operaciones a aprovar
function OBT_MONTO_RIESGO (vnro_solicitud varchar2)
return number
is
vmonto_pr number:= null;
vresult number:= 0;
begin

  select nvl(t.sal_capital,0)+nvl(t.sal_int_adelantado,0) into vmonto_pr
  from pr_cta_prestamos t
  where t.nro_solicitud = vnro_solicitud;

  if(vmonto_pr is not null) then
               vresult := nvl(vmonto_pr,0);
  end if;

  return vresult;
end;

--Actualiza categoria de clientes
PROCEDURE act_cat_clientes is
 /*   cursor c_datos is
    select to_char(a.numclien) numclien,
            case
             when a.ncalifbcp = ' ' or a.ncalifbcp  is null then
                '1' --- valor por defecto
             else a.ncalifbcp
           end calif
      from simgia_bcdt001 a, ba_personas p
     where to_char(a.numclien) = p.cod_persona;*/
begin/*
   for x in c_datos loop
      begin
         update  ge_clientes c
            set c.cat_riesgo = x.calif,
                c.cat_automatica = x.calif,
                c.cat_subjetiva = x.calif
          where c.cod_persona = x.numclien;
      exception
         when others then
            raise_application_error(-20001, 'Error al actualizar datos, cliente: '||x.numclien||': '||sqlerrm);
      end;
   end loop;
   commit;*/
/*
exception
   when others then
      raise_application_error(-20000, 'Error al actualizar datos:'||sqlerrm);*/
      null;
end;

-- Migracion de categoria de clientes
procedure migrar_interfaz8 is
v_date date;
begin
  prg_gen_archivo_txt('migra8.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
  ctrl_interfaz8;
end;

--Se utiliza entra procesos independientes, crea un delay por el tiempo que sea necesario
procedure ctrl_interfaz8 is
vcont number;
vresult number;
vdate date;
begin
    --se consulta estado de la migracion
    --0 aun no termina
    --1 terminada
    vcont := 0;
    select pai_int.ctrl_migra('INTERFAZ8') into vresult from dual;
    WHILE vresult = 0 LOOP
        --delay de 30 segs
        vdate :=  pai_int.smg_sleep('30');
        --consulta estado de la migracion
        select pai_int.ctrl_migra('INTERFAZ8') into vresult from dual;
        vcont := vcont + 1;
        if(vcont > 100) then
             RAISE_APPLICATION_ERROR(-20000,'Interfaz8 esta tardando mas de 50min. Controlar logs de la migracion.');
        end if;
    END LOOP;
end;

--Prueba de tarjetas
-- Backup vistas AS400
procedure backup_vistas_t is
v_date date;
begin

   /*v_date := pag_cal.fu_obt_fec_actual(6);

   -- tarjetas
   execute immediate 'truncate table SIMGIA_MAECARTERA_F4_bkp';

   insert into Simgia_Maecartera_f4_bkp select t.*, v_date from Simgia_Maecartera_t t ;*/
   null;
end;

-- Migracion de debcrecont
procedure migrar_interfaz9 is
v_date date;
begin
  --trunca tabla debcrecont
  execute immediate 'truncate table simgia_debcrecont';
  prg_gen_archivo_txt('migra9.run','select ' || CHR(39) || 'ON'|| CHR(39) || ' from dual','N',null,'N');
  --se espera 60 segundos a que termine la migración
  v_date :=  pai_int.smg_sleep('60');
end;

--Actualiza categoria subjetiva de clientes con datos de MAERECLAS
PROCEDURE act_catsub_clientes is
    cursor c_datos is
    select to_char(a.RCRIESGO) numclien,
            case
             when a.RCRECLASIF = ' ' or a.RCRECLASIF  is null then
                '1' --- valor por defecto
             else a.RCRECLASIF
           end calif
      from simgia_MAERECLAS a, ba_personas p
     where to_char(a.RCRIESGO) = p.cod_persona
     and a.RCRECLASIF <> 0;
begin
   for x in c_datos loop
      begin
         update  ge_clientes c
            set c.cat_subjetiva = x.calif
          where c.cod_persona = x.numclien;
      exception
         when others then
            raise_application_error(-20001, 'Error al actualizar datos, cliente: '||x.numclien||': '||sqlerrm);
      end;
   end loop;
   commit;
exception
   when others then
      raise_application_error(-20000, 'Error al actualizar datos:'||sqlerrm);
end;

-- Crea archivo de texto de PREVICAR
procedure GEN_PREVICAR_PAG is

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
p_corte number:= 9000;

begin

      -- se consulta cantidad de registros
      select count(*) into v_cant from simgia_previcar_bkp;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'PREPREVICA.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select linea from simgia_previcar_bkp where ID <= ' || v_fin || ' and ID >= ' || v_ini ;


        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;

end;

end PAI_INT_F4;
/

