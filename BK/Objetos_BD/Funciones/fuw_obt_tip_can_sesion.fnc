CREATE OR REPLACE FUNCTION IT.fuw_obt_tip_can_sesion(p_sesion IN VARCHAR2) RETURN VARCHAR2 IS
  v_os_dispositivo      bw_dispositivos.os%TYPE;
  v_cod_dispositivo     bw_dispositivos.id_dispositivo%TYPE;
  v_cod_per_dispositivo bw_ses_informacion.cod_per_dispositivo%TYPE;
  v_cod_usuario         ba_usuarios.cod_usuario%TYPE := USER;
  v_des_canal           VARCHAR2(15);
  v_exi_info_sesion     VARCHAR2(1);
  v_exi_dispositivo     VARCHAR2(1);
BEGIN
	
   -- Obtenemos la realcion de dispositivo por sesion
   BEGIN
     SELECT s.cod_per_dispositivo
       INTO v_cod_per_dispositivo
       FROM it.bw_ses_informacion s
      WHERE s.nro_sesion = p_sesion;
      v_exi_info_sesion := 'S';
   EXCEPTION
      WHEN OTHERS THEN
        v_cod_per_dispositivo := NULL;
        v_exi_info_sesion     := 'N';
   END;
   
   -- Obtenemos el cod. Dispositivo en base a la releacion persona dispositivo
   BEGIN
     SELECT t.cod_dispositivo
       INTO v_cod_dispositivo
       FROM it.bw_per_dispositivos t
      WHERE t.cod_relacion = v_cod_per_dispositivo;
      v_exi_dispositivo := 'S';
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_dispositivo  := NULL;
         v_exi_dispositivo  := 'N';
   END;
   

   -- Obtenemos el OS del dispositivo
   BEGIN
     SELECT t.os
       INTO v_os_dispositivo
       FROM it.bw_dispositivos t
      WHERE t.id_dispositivo = v_cod_dispositivo;
   EXCEPTION
      WHEN OTHERS THEN
         v_os_dispositivo  := NULL;
   END;

   -- Si existe informacion de la sesion y informacion del dispositivo obtenemos el canal utilizado
   IF ( nvl(v_exi_info_sesion,'N') = 'S' AND
           nvl(v_exi_dispositivo,'N') = 'S' ) THEN
           
	       IF  ( ( INSTR(UPPER(v_os_dispositivo),'ANDROID') > 0 ) 
	              OR ( INSTR(UPPER(v_os_dispositivo),'IOS') > 0 )  ) THEN
	              
		         IF (v_cod_usuario = 'HBANKJ') THEN
		         
		             v_des_canal := 'APP_EMPRESAS';
		                
		         ELSIF (v_cod_usuario = 'HBANKF') THEN 
		         
		             v_des_canal := 'APP_INDIVIDUOS';
		                
	             ELSE 
	             
	                 v_des_canal := NULL;
	                 
		         END IF;
	      
	       ELSE
	             IF (v_cod_usuario = 'HBANKJ') THEN
		         
		             v_des_canal := 'WEB_EMPRESAS';
		             
		         ELSIF (v_cod_usuario = 'HBANKF') THEN 
		         
		             v_des_canal := 'WEB_INDIVIDUOS';
		             
		         ELSE 
		         
		             v_des_canal := NULL;
		             
		         END IF;
	       
	       END IF;
       
   ELSE
         v_des_canal := NULL;
   END IF;

   RETURN v_des_canal;
END;