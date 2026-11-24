CREATE OR REPLACE TRIGGER IT.TA_TA_SOLICITUDES_TMP
AFTER  INSERT ON TA_SOLICITUDES_TMP
FOR EACH ROW

DECLARE
  v_nro_solicitud  ta_solicitudes.nro_solicitud%type;
  v_cod_persona    ba_personas.cod_persona%type;
  v_afinidad       ta_solicitudes.afinidad%type;
  v_cod_modalidad  ge_modalidades.cod_modalidad%type;
  v_nom_embozado   ta_solicitudes.nom_embozado%type;
  v_sub_afinidad   ta_solicitudes.sub_afinidad%type;
  v_referencia     ge_dir_envios.referencia%type;
  v_pre_embozada   varchar2(1);
  v_obs            ta_solicitudes.observacion%type;
  v_ref_persona    ba_cod_referencias.val_minimo%type;
  v_par_modalidad  ge_par_dinamicos.val_parametro%type;
BEGIN
 IF INSERTING THEN
 --*
 --*  Traer secuencia para nro. de solicitud
 --*
 Begin
   SELECT  S_NRO_SOLICITUD.NEXTVAL
     into v_nro_solicitud
     FROM SYS.DUAL;
 Exception
   when others then
     RAISE_APPLICATION_ERROR(-20001,'Error al traer secuencia de solicitudes : '||sqlerrm);
 End;
 --*
 --* Ttaer cod. de persona
 --*
 Begin
   Select p.cod_persona
     into v_cod_persona
     from ba_personas p
    where p.nro_documento = :NEW.nro_documento;
 Exception
   when others then
     RAISE_APPLICATION_ERROR(-20001,'Error al traer codigo de Persona para el documento : '||:new.nro_documento ||' Error : '||sqlerrm);
 End;
 -- Recuperar Equivalencia de la afinidad con el SIGRIM -- ICL. 08/07/2009
 -- Temporal hasta que se saque el SIGRIM
 
   v_afinidad := null;
   v_sub_afinidad := null;
   Begin
      select substr(val_minimo,1,6), substr(val_minimo,7,3)
        into v_afinidad, v_sub_afinidad
        from ba_cod_referencias
       where dominio = 'EQU_AFINIDAD'
         and val_maximo = :new.referencia
         and abreviatura = :new.afinidad;
      exception
         when no_data_found then
            raise_application_error(-20000,'Afinidad SIGRIM no definida');
         when others then
            raise_application_error(-20000,'Error al buscar Afinidad SIGRIM : '||sqlerrm);
   End;

   -- Recuperar la modalidad a partir de la afinidad -- ICL. 08/07/2009
   if v_afinidad is not null then
      Begin
         select distinct cod_modalidad, sub_afinidad
           into v_cod_modalidad, v_sub_afinidad
           from ta_tipos t
          where t.afinidad = v_afinidad
            and nvl(t.sub_afinidad,'00') = nvl(v_sub_afinidad,'00');
      exception
         when no_data_found then
            raise_application_error(-20000,'Modalidad no registrada para la afinidad '||v_afinidad||' sub-afinidad '||v_sub_afinidad);
         when others then
            raise_application_error(-20000,'Error al buscar Modalidad en ta_tipos : '||sqlerrm);
      end;
   end if;
   v_ref_persona := FUE_OBT_DES_REFCODES('COD_PER_EXC_IMP', v_cod_persona);
   v_par_modalidad := fug_obt_pardinamico('COD_MAD_EXC_IMP', '5', v_cod_modalidad);
   if :new.monto <> 0 or ( v_par_modalidad = 'S' ) then
     --- Recuperar embozado
     v_nom_embozado := :new.nom_embozado;
     if :new.nom_embozado is null then
       IF (v_ref_persona = 'S'  and v_par_modalidad = 'S' ) then
        -- Control para excluir de la validacion a personas juridicas y la nueva modalidad 501 BANCARDCHECK  -- GC 30/11/2012
           v_nom_embozado := '';
        ELSE
          Begin
             select substr(trim(pri_nombre)||' '||trim(pri_apellido),1,20)
               into v_nom_embozado
               from ba_per_fisicas
              where cod_persona = v_cod_persona;
          exception
             when no_data_found then
                raise_application_error(-20000,'Persona '||v_cod_persona||' no registrada como física');
             when others then
                raise_application_error(-20000,'Error al buscar persona : '||sqlerrm);
          End;
        END IF;
     end if;
     --* Recuperar direccion de envio  --Icl 10/07/09  RI
     v_referencia := :new.referencia;
     if  nvl(:new.tip_Envio,'D') = 'D' then
         Begin
          select cod_direccion into v_referencia
            from ba_direcciones
           where cod_persona = v_cod_persona
             and cod_direccion = v_referencia;
         Exception
          when no_Data_found then
            Begin
             select cod_direccion into v_referencia
              from ba_direcciones
             where cod_persona = v_cod_persona
               and rownum = 1;
            Exception
             when others then
                v_referencia := 1;
            End;
          when others then
             v_referencia := 1;
          End;
      elsif :new.tip_envio = 'R' then
         v_referencia := 1;   --oficina principal
      end if;
 end if;
 --*
 --* RI : 03/03/2010 : Si viene del programa de Solicitudes Pre Embozadas, marcar que la
 --* Solicitud es Pre Embozada.
 --*
 if nvl(PAE_CNF.G_PROGRAMA,'x') = 'TPSOLPRE' then
    v_pre_embozada := 'S';
 end if;
 If v_pre_embozada = 'S' then
    v_obs := 'Alta Masiva de Tarjetas PreEmbozadas.';
 else
    v_obs := 'Alta Masiva de Tarjetas.';
 end if;
 --*
 --*  Insertar tabla TA_SOLICITUDES
 --*

 if :new.monto <> 0 or (v_par_modalidad = 'S' )then
  INSERT INTO TA_SOLICITUDES
  (NRO_SOLICITUD          ,
   COD_PERSONA            ,
   COD_OFICINA            ,
   COD_MODULO             ,
   COD_MODALIDAD          ,
   COD_USU_PROMOTOR       ,
   FEC_SOLICITUD          ,
   COD_USU_OFICIAL        ,
   FEC_APROBACION         ,
   COD_CAUSA              ,
   DEB_AUTOMATICO         ,
   NRO_CTA_DEBITO         ,
   TIP_COBRO              ,
   NOM_EMBOZADO           ,
   LIN_SUGERIDA           ,
   MONTO                  ,
   PUNTAJE                ,
   COD_ESTADO             ,
   COD_EST_SUGERIDO       ,
   TAS_INT_ADELANTO       ,
   TAS_FINANCIACION       ,
   TAS_MORA               ,
   MTO_MIN_PAGO           ,
   POR_PAG_MINIMO         ,
   TIP_ENVIO              ,
   REFERENCIA             ,
   USU_INSERCION          ,
   FEC_INSERCION          ,
   USU_MODIFICACION       ,
   FEC_MODIFICACION       ,
   NRO_LINEA              ,
   OBSERVACION            ,
   COD_MONEDA             ,
   COD_CAMPANA            ,
   COD_CANAL              ,
   MTO_APROBADO           ,
   NIV_APROBACION         ,
   NRO_ACTA               ,
   NRO_CUENTA             ,
   AFINIDAD,
   SUB_AFINIDAD           ,
   PRE_EMBOZADA        )
  values
   (v_nro_solicitud,
    v_cod_persona,
   :NEW.COD_OFICINA            ,
   5,
   V_COD_MODALIDAD          ,
   NULL,
   NVL(trunc(:NEW.FEC_SOLICITUD),TRUNC(SYSDATE))     ,
   NULL,
   NVL(trunc(:NEW.FEC_APROBACION), TRUNC(SYSDATE))   ,
   NULL,
   :NEW.DEB_AUTOMATICO         ,
   :NEW.NRO_CTA_DEBITO         ,
   :NEW.TIP_COBRO              ,
    V_NOM_EMBOZADO           ,
   NULL,
   :NEW.MONTO                  ,
   NULL,
   'APR',
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   nvl(:NEW.TIP_ENVIO,'D') ,
   v_referencia,
   USER,
   SYSDATE,
   USER,
   SYSDATE,
   NULL,
   v_obs,
   'GS',
   NULL,
   NULL,
   :NEW.MONTO,
   NULL,
   NULL,
   NULL,
   v_afinidad,
   v_sub_afinidad,
   v_pre_embozada  );
 end if;
END IF;

EXCEPTION
   when others then
        raise_application_error(-20000,'Alta Masiva de Solicitudes ' || sqlerrm);
END;
/

