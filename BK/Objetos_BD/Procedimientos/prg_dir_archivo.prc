CREATE OR REPLACE Procedure IT.PRG_DIR_ARCHIVO Is
		 Cursor CUR_DIRECCIONES Is
					Select NRO_CUENTA,
								 DIRECCION1,
								 DIRECCION2,
								 DIRECCION3,
								 CIUDAD,
								 PROCESADO
						From GE_DIR_BANCARD_TMP
            WHERE PROCESADO = 'N';
     --VARIABLES
     VSI_PROCESO Varchar2(1);   -- indica si fue procesado o no.
		 VMENSAJE    Varchar2(500); -- guarda el mensaje del proceso realizado.
     
		 --VARIABLES PARA CONTROL DE EJECUCION SEGUN HORA ESTABLECIDA EN EL PARAMETRO
		 VHORA_PARAMETRO Varchar2(5) Default SUBSTR(FUG_OBT_PARDINAMICO('INI_HORA'),1,5);
		 VHORA_ACTUAL    Varchar2(5) Default TO_CHAR(Sysdate, 'HH24:MI');
BEGIN
  --Verifica la hora para la ejecución del proceso
		 If VHORA_ACTUAL >= VHORA_PARAMETRO Then
					
          --recorre los registros de la tabla temporal
					For REG In CUR_DIRECCIONES Loop
				            -- procedimiento donde va a actualizar o insertar la direccion 
										-- y ciudad del cliente según su nro de cuenta
										PRG_UPD_DIR_CLIENTES(REG.NRO_CUENTA, REG.DIRECCION1,
																				 REG.DIRECCION2, REG.DIRECCION3,
																				 REG.CIUDAD, VSI_PROCESO, VMENSAJE);
										
                    --actualiza el estado y la observacion('OK' si todo salio bien o 
										--                                      algun mensaje de error si asi fue)
										Update GE_DIR_BANCARD_TMP T
											 Set T.PROCESADO   = VSI_PROCESO,
													 T.OBSERVACION = SUBSTR(Trim(VMENSAJE), 1, 500)
										 Where NVL(T.NRO_CUENTA, Rowid) = NVL(REG.NRO_CUENTA, Rowid);
										--graba en la BD
										Commit;
					End Loop;
		 Else
					RAISE_APPLICATION_ERROR(-20000,
																	'La hora establecida para ejecutar el proceso es a partir de las '||VHORA_PARAMETRO);
		 End If;
End;
/

