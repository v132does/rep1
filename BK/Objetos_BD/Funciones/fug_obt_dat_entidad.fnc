CREATE OR REPLACE FUNCTION IT.FUG_OBT_DAT_ENTIDAD (
P_OPCION IN VARCHAR2,
P_FECHA IN varchar2,
p_tipo  in varchar2)
RETURN VARCHAR2
IS
 /*p_opcion: NOM (Nombre Entidad)/RUC (ruc)/LOGO (nombre de logo a mostrar)
   p_fecha: Fecha para validar fecha desde de cambio de marca
   p_tipo: CO(Comprobante)/ FA(Factura)
   11198 Código de Persona del Banco
 */
 v_fec_cam_par           varchar2(20) := fug_obt_pardinamico('CAM_MAR_LOG_COM');
 v_fec_cam_log_par       varchar2(20) := fug_obt_pardinamico('FEC_NUE_BANCO');
 v_fec_fus_leg_par       varchar2(20) := fug_obt_pardinamico('FEC_FUS_LEGAL');
 v_fec_cam_leg_par       varchar2(20) := fug_obt_pardinamico('CAM_MAR_FEC_LEGAL');
 v_fec_cam_ruc_par       varchar2(20) := fug_obt_pardinamico('CAM_RUC_FEC_LEGAL');

 v_fec_cam           varchar2(20) ;
 v_fec_cam_log       varchar2(20) ;
 v_fec_cam_leg       varchar2(20) ;
 v_fec_cam_ruc       varchar2(20) ;
 v_fec_fus_leg       varchar2(20) ;

 v_fec_cam_d           varchar2(20) ;
 v_fec_cam_log_d       varchar2(20) ;
 v_fec_cam_leg_d       varchar2(20) ;
 v_fec_cam_ruc_d       varchar2(20) ;
 v_fec_fus_leg_d       varchar2(20);

 v_fec_par           date;
 v_retorno           ge_par_generales.nom_entidad%type;
BEGIN
 if P_FECHA is null or P_OPCION is null then
     v_retorno:= 'Error - Fecha y/o tipo no puede ser nulo';
 end if;
 --Fecha log
 if v_fec_cam_par is not null then
    v_fec_cam:= substr(v_fec_cam_par,1,2)||'/'||substr(v_fec_cam_par,3,2)||'/'||substr(v_fec_cam_par,5,4);
    v_fec_cam_d:= to_date(v_fec_cam,'dd/mm/yyyy');
 end if;
 --Fecha log fac
  if v_fec_cam_log_par is not null then
    v_fec_cam_log:= substr(v_fec_cam_log_par,1,2)||'/'||substr(v_fec_cam_log_par,3,2)||'/'||substr(v_fec_cam_log_par,5,4);
    v_fec_cam_log_d:= to_date(v_fec_cam_log,'dd/mm/yyyy');
  end if;
 --Fecha  fac marca
  if v_fec_cam_leg_par is not null then
    v_fec_cam_leg:= substr(v_fec_cam_leg_par,1,2)||'/'||substr(v_fec_cam_leg_par,3,2)||'/'||substr(v_fec_cam_leg_par,5,4);
    v_fec_cam_leg_d:= to_date(v_fec_cam_leg,'dd/mm/yyyy');
  end if;

   --Fecha  ruc fac
  if v_fec_cam_ruc_par is not null then
    v_fec_cam_ruc:= substr(v_fec_cam_ruc_par,1,2)||'/'||substr(v_fec_cam_ruc_par,3,2)||'/'||substr(v_fec_cam_ruc_par,5,4);
    v_fec_cam_ruc_d:= to_date(v_fec_cam_ruc,'dd/mm/yyyy');
  end if;
  --Fecha fusion legal
  if v_fec_fus_leg_par is not null then
    v_fec_fus_leg:= substr(v_fec_fus_leg_par,1,2)||'/'||substr(v_fec_fus_leg_par,3,2)||'/'||substr(v_fec_fus_leg_par,5,4);
    v_fec_fus_leg_d:= to_date(v_fec_fus_leg,'dd/mm/yyyy');
  end if;

 v_fec_par := to_date(p_fecha,'dd/mm/yyyy');
 If p_tipo ='FA' then
     if upper(P_OPCION)='NOM' then
       if v_fec_par >= v_fec_fus_leg_d then
         v_retorno :=  fug_obt_pardinamico('NOM_GNB_LEGAL');
       else
         if v_fec_par < v_fec_cam_leg_d then
           v_retorno:= fug_obt_pardinamico('NOM_ENTIDAD_LEGACY');
         else
            v_retorno:= fug_obt_pardinamico('NOM_GNB_LARGO');
         end if;
       end if;
     elsif  upper(P_OPCION)='RUC' then
       if v_fec_par >= v_fec_fus_leg_d then
          v_retorno := fug_obt_pardinamico('RUC_GNB_LEGAL');
       else
         if v_fec_par < v_fec_cam_ruc_d then
            v_retorno:= fug_obt_pardinamico('RUC_ENTIDAD_LEGACY');
         else
            v_retorno:= fug_obt_pardinamico('RUC_GNB_NUEVO');
         end if;
       end if;
     elsif  upper(P_OPCION)='LOGO' then
       if v_fec_par >= v_fec_fus_leg_d then
         -- parametrizar el nombre de la entidad nvo.
         v_retorno:= 'LOGO';  -- logo GNB PY
       else
         if v_fec_par < v_fec_cam_log_d then
            v_retorno:= 'LOGO1';  -- logo BBVA
         else
            --v_retorno:= 'LOGO';
            v_retorno:= 'LOGO2';  -- logo GNB Fusion
         end if;
       end if;
     elsif  upper(P_OPCION)='BW_LOGO' then
       -- logo para Banca Web
       if v_fec_par >= v_fec_fus_leg_d then
         -- logo posterior a fusion legal: GNB Py
         v_retorno:= fug_obt_pardinamico('IMG_ENTIDAD_LOGO');
       else
         if v_fec_par < v_fec_cam_log_d then
            -- logo BBVA
            v_retorno:= fug_obt_pardinamico('IMG_ENTIDAD_LEGACY_LOGO');
         else
            -- logo GNB Fusion
            v_retorno:= fug_obt_pardinamico('IMG_ENTIDAD_FUSION_LOGO');
         end if;
       end if;
      ELSE
        v_retorno:='Error - Opción recibida, no definido: '||p_opcion;

      END IF;
else
    --Comprobante
    if upper(P_OPCION)='NOM' then
       if v_fec_par >= v_fec_fus_leg_d then
         -- parametrizar el nombre de la entidad nvo.
         v_retorno := fug_obt_pardinamico('NOM_GNB_LEGAL');
       else
         if v_fec_par <= v_fec_cam_d then
           v_retorno:= fug_obt_pardinamico('NOM_ENTIDAD_LEGACY');
         else
            v_retorno:= fug_obt_pardinamico('NOM_GNB_LARGO');
         end if;
       end if;
     elsif  upper(P_OPCION)='RUC' then
       if v_fec_par >= v_fec_fus_leg_d then
         -- parametrizar el nombre de la entidad nvo.
         v_retorno := fug_obt_pardinamico('RUC_GNB_LEGAL');
       else
         if v_fec_par <= v_fec_cam_d then
            v_retorno:= fug_obt_pardinamico('RUC_ENTIDAD_LEGACY');
         else
            v_retorno:= fug_obt_pardinamico('RUC_GNB_NUEVO');
         end if;
       end if;
     elsif  upper(P_OPCION)='LOGO' then
       if v_fec_par >= v_fec_fus_leg_d then
         -- parametrizar el nombre de la entidad nvo.
         v_retorno:= 'LOGO';
       else
         if v_fec_par <= v_fec_cam_d then
            v_retorno:= 'LOGO1';
         else
            v_retorno:= 'LOGO2';
         end if;
       end if;
     elsif  upper(P_OPCION)='BW_LOGO' then
       -- logo para Banca Web
       if v_fec_par >= v_fec_fus_leg_d then
         -- logo posterior a fusion legal: GNB Py
         v_retorno:= fug_obt_pardinamico('IMG_ENTIDAD_LOGO');
       else
         if v_fec_par < v_fec_cam_log_d then
         -- logo BBVA
            v_retorno:= fug_obt_pardinamico('IMG_ENTIDAD_LEGACY_LOGO');
         else
           -- logo GNB Fusion
            v_retorno:= fug_obt_pardinamico('IMG_ENTIDAD_FUSION_LOGO');
         end if;
       end if;
      ELSE
        v_retorno:='Error - Opción recibida, no definido: '||p_opcion;

      END IF;

  end if;

   return v_retorno;

END;
/

