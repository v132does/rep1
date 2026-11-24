CREATE OR REPLACE FUNCTION IT.FUG_OBT_PRO_DAT_CTA
 (P_COD_MODULO    IN GE_CUENTAS.COD_MODULO%TYPE,
  P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE,
  P_TIPO          IN VARCHAR2 default 'C') --Valores (S/C) Si es solicitud o cuenta
  return varchar2
  is

  v_nom_programa ba_programas.cod_programa%type;

begin
   If p_cod_modalidad in (31,334) Then
       v_nom_programa := 'EAMANCAV';
   Elsif p_cod_modalidad = 32 Then
       v_nom_programa := 'EAMANCPF';
   Elsif p_cod_modalidad = 37 Then
       v_nom_programa := 'EAMANPLZ';
   Elsif p_cod_modalidad = 38 Then
       v_nom_programa := 'EAMANAHP';       
   Elsif p_cod_modalidad = 33 or p_cod_modalidad IN (34,35) or p_cod_modalidad = 36 Then
       v_nom_programa := 'EAMANCDA';
   Elsif p_cod_modulo = 4 and p_cod_modalidad = 41 and p_tipo = 'C' then
       v_nom_programa := 'CMCTACTE';
   Elsif p_cod_modulo = 4 and p_tipo = 'S' then
       v_nom_programa := 'CMLINSOB';
   --WA:31/07/2014 se comenta, no corresponde a implementación
   --Elsif p_cod_modulo = 4 and p_cod_modalidad  = 49  Then
      --v_nom_programa := 'CMSOBVEN';
   Elsif p_cod_modulo = 4 and p_cod_modalidad <> 41 Then
       v_nom_programa := 'CMCTABAN';
   Elsif p_cod_modulo = 5 and p_tipo = 'C' Then
       v_nom_programa := 'ETMANTAR';
   Elsif p_cod_modulo = 5 and p_tipo = 'S' Then
      v_nom_programa := 'TMSOLICI';
   Elsif p_cod_modulo = 5 and p_tipo = 'A' Then
      v_nom_programa := 'TMSOLLIN';
   Elsif p_cod_modulo = 6 and p_tipo = 'C' Then
       v_nom_programa := 'EPMANPRE';
   Elsif p_cod_modulo = 6 and p_tipo = 'F' Then
       v_nom_programa := 'PMDESVEC';
   Elsif p_cod_modulo = 6 and p_tipo = 'S' Then
     If FUP_OBT_TIP_DESCUENTO(p_cod_modalidad) is null then
      v_nom_programa := 'EPPROCOR';
     Else
      v_nom_programa := 'PMDESDOC';
     End if;
   Elsif p_cod_modulo = 7 Then
       v_nom_programa := 'ELMANCAM';
   Elsif p_cod_modulo = 8 and p_cod_modalidad = 81 Then
       v_nom_programa := 'XMIMPORT';
   Elsif p_cod_modulo = 8 and p_cod_modalidad = 82 Then
       v_nom_programa := 'XMEXPORT';
   Elsif p_cod_modulo = 8 and p_cod_modalidad IN  (87,88,89)  Then
       v_nom_programa := 'XMFIANZA';
   Elsif p_cod_modulo = 8 and p_cod_modalidad IN  (83,84)  Then
       v_nom_programa := 'XMCOBRAN';
   Elsif p_cod_modulo = 10  Then
      ---CNFREINT-1  Repo Interbancario  - LCABRERA JULIO/2015
      v_nom_programa := fue_obt_des_refcodes('MES_PRO_MODALIDAD', p_cod_modalidad);
     /* if p_cod_modalidad in (109,112,117,118,119,115,126) Then
         v_nom_programa := 'MMCTAPRE';
      elsif p_cod_modalidad = 145 then
         v_nom_programa := 'MMANTIMP';
      else
           v_nom_programa := 'MMCTADOC';
      end if;*/
   Elsif p_cod_modulo = 15 Then
       v_nom_programa := 'VCOPEVEN';
   --se agregó para garantía y límite
   elsif p_tipo = 'G' then --garantía
      v_nom_programa := 'EPGARPRE';
   elsif p_tipo = 'L' then --límite de crédito
      v_nom_programa := 'PMSOLLIM';
   elsif p_tipo = 'B' then --límite de crédito global
      v_nom_programa := 'PMSOLLIG';
   elsif p_tipo = 'D' then --tarjeta de débito
      v_nom_programa := 'AMTARDEB';
   elsif p_tipo = 'J' then --caja  de seguridad
      v_nom_programa := 'QMCONTRA';
   elsif P_TIPO = 'O' then
      v_nom_programa := 'LMOPEFUT';
   elsif P_TIPO = 'U' then
      v_nom_programa := 'GMVALCUS';
   elsif P_TIPO = 'F' then
      v_nom_programa := 'CMCUSCHE';
   End If;
   return v_nom_programa ;
end fug_obt_pro_dat_cta;
/

