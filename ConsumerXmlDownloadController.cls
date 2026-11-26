public with sharing class ConsumerXmlDownloadController {
    private static final Integer BATCH_SIZE = 80;
    
    public class XmlDownloadResult {
        @AuraEnabled
        public String fileName;
        
        @AuraEnabled
        public String base64Content;
        
        @AuraEnabled
        public Integer contentSize;
    }
    public class XmlBatchResult {
        @AuraEnabled
        public List<XmlDownloadResult> files;

        @AuraEnabled
        public Datetime nextCreatedDate;

        @AuraEnabled
        public Id nextReportId;

        @AuraEnabled
        public Boolean hasMore;
}
@AuraEnabled(cacheable=true)
public static Integer getXmlCount(
    Date startDate,
    Date endDate
) {
    if (startDate == null || endDate == null) {
        return 0;
    }

    Datetime startDateTime =
        Datetime.newInstance(
            startDate,
            Time.newInstance(0, 0, 0, 0)
        );

    Datetime endDateTime =
        Datetime.newInstance(
            endDate.addDays(1),
            Time.newInstance(0, 0, 0, 0)
        );

    return [
        SELECT COUNT()
        FROM forseva1__EquifaxConsumer__c
        WHERE forseva1__Report_Response__c != null
        AND CreatedDate >= :startDateTime
        AND CreatedDate < :endDateTime
    ];
}
@AuraEnabled
public static XmlBatchResult getXmlBatch(
    Date startDate,
    Date endDate,
    Datetime lastCreatedDate,
    Id lastReportId
) {
    if (startDate == null || endDate == null) {
        throw new AuraHandledException(
            'Start Date and End Date are required.'
        );
    }

    if (startDate > endDate) {
        throw new AuraHandledException(
            'Start Date cannot be after End Date.'
        );
    }

    Datetime startDateTime =
        Datetime.newInstance(
            startDate,
            Time.newInstance(0, 0, 0, 0)
        );

    Datetime endDateTime =
        Datetime.newInstance(
            endDate.addDays(1),
            Time.newInstance(0, 0, 0, 0)
        );
    Integer queryLimit =
    BATCH_SIZE + 1;

    List<forseva1__EquifaxConsumer__c> reports;

    if (
        lastCreatedDate == null ||
        lastReportId == null
    ) {
        reports = [
            SELECT
                Id,
                Name,
                CreatedDate,
                forseva1__Account__c,
                forseva1__Account__r.Name,
                forseva1__Report_Response__c
            FROM forseva1__EquifaxConsumer__c
            WHERE forseva1__Report_Response__c != null
            AND CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            ORDER BY CreatedDate ASC, Id ASC
            LIMIT :queryLimit
        ];
    } else {
        reports = [
            SELECT
                Id,
                Name,
                CreatedDate,
                forseva1__Account__c,
                forseva1__Account__r.Name,
                forseva1__Report_Response__c
            FROM forseva1__EquifaxConsumer__c
            WHERE forseva1__Report_Response__c != null
            AND CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            AND (
                CreatedDate > :lastCreatedDate
                OR (
                    CreatedDate = :lastCreatedDate
                    AND Id > :lastReportId
                )
            )
            ORDER BY CreatedDate ASC, Id ASC
            LIMIT :queryLimit
        ];
    }

    XmlBatchResult batch =
        new XmlBatchResult();

    batch.files =
        new List<XmlDownloadResult>();

    batch.hasMore =
        reports.size() > BATCH_SIZE;

    Integer recordsToProcess =
        Math.min(
            reports.size(),
            BATCH_SIZE
        );

    for (
        Integer index = 0;
        index < recordsToProcess;
        index++
    ) {
        forseva1__EquifaxConsumer__c report =
            reports[index];

        PageReference xmlPage =
            new PageReference(
                '/apex/forseva1__ReportResponseData'
            );

        xmlPage.getParameters().put(
            'id',
            String.valueOf(
                report.forseva1__Report_Response__c
            )
        );

        xmlPage.getParameters().put(
            'format',
            'xml'
        );

        Blob xmlContent;

        try {
            xmlContent =
                xmlPage.getContent();
        } catch (Exception error) {
            throw new AuraHandledException(
                'XML generation failed for ' +
                report.Name +
                ': ' +
                error.getMessage()
            );
        }

        if (
            xmlContent == null ||
            xmlContent.size() == 0
        ) {
            throw new AuraHandledException(
                'Generated XML was empty for ' +
                report.Name +
                '.'
            );
        }

        String accountName =
            report.forseva1__Account__r != null
                ? report.forseva1__Account__r.Name
                : 'UnknownAccount';

        accountName =
            accountName.replaceAll(
                '[\\\\/:*?"<>|]',
                '_'
            );

        XmlDownloadResult result =
            new XmlDownloadResult();

        result.fileName =
            accountName +
            '_' +
            report.Name +
            '.xml';

        result.base64Content =
            EncodingUtil.base64Encode(
                xmlContent
            );

        result.contentSize =
            xmlContent.size();

        batch.files.add(result);
    }

    if (recordsToProcess > 0) {
        forseva1__EquifaxConsumer__c lastReport =
            reports[recordsToProcess - 1];

        batch.nextCreatedDate =
            lastReport.CreatedDate;

        batch.nextReportId =
            lastReport.Id;
    }

    return batch;
}
    @AuraEnabled
    public static List<XmlDownloadResult> getFiveXmlFiles(
        Date startDate,
        Date endDate
    ) {
        if (startDate == null || endDate == null) {
            throw new AuraHandledException(
                'Start Date and End Date are required.'
            );
        }
        
        if (startDate > endDate) {
            throw new AuraHandledException(
                'Start Date cannot be after End Date.'
            );
        }
        
        Datetime startDateTime =
            Datetime.newInstance(
                startDate,
                Time.newInstance(0, 0, 0, 0)
            );
        
        Datetime endDateTime =
            Datetime.newInstance(
                endDate.addDays(1),
                Time.newInstance(0, 0, 0, 0)
            );
        
        List<forseva1__EquifaxConsumer__c> reports = [
            SELECT
            Id,
            Name,
            CreatedDate,
            forseva1__Account__c,
            forseva1__Account__r.Name,
            forseva1__Report_Response__c
            FROM forseva1__EquifaxConsumer__c
            WHERE forseva1__Report_Response__c != null
            AND CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            ORDER BY CreatedDate ASC
            LIMIT 10
        ];
        
        List<XmlDownloadResult> results =
            new List<XmlDownloadResult>();
        
        for (
            forseva1__EquifaxConsumer__c report : reports
        ) {
            PageReference xmlPage =
                new PageReference(
                    '/apex/forseva1__ReportResponseData'
                );
            
            xmlPage.getParameters().put(
                'id',
                String.valueOf(
                    report.forseva1__Report_Response__c
                )
            );
            
            xmlPage.getParameters().put(
                'format',
                'xml'
            );
            
            Blob xmlContent =
                xmlPage.getContent();
            
            XmlDownloadResult result =
                new XmlDownloadResult();
            
            String accountName =
                report.forseva1__Account__r != null
                ? report.forseva1__Account__r.Name
                : 'UnknownAccount';
            
            accountName =
                accountName.replaceAll(
                    '[\\\\/:*?"<>|]',
                    '_'
                );
            
            result.fileName =
                accountName +
                '_' +
                report.Name +
                '.xml';
            
            result.base64Content =
                EncodingUtil.base64Encode(
                    xmlContent
                );
            
            result.contentSize =
                xmlContent.size();
            
            results.add(result);
        }
        
        return results;
    }
    @AuraEnabled
    public static XmlDownloadResult getXml(
        Id consumerReportId
    ) {
        if (consumerReportId == null) {
            throw new AuraHandledException(
                'Consumer Report ID is required.'
            );
        }
        
        forseva1__EquifaxConsumer__c report = [
            SELECT
            Id,
            Name,
            forseva1__Report_Response__c
            FROM forseva1__EquifaxConsumer__c
            WHERE Id = :consumerReportId
            LIMIT 1
        ];
        
        if (
            report.forseva1__Report_Response__c == null
        ) {
            throw new AuraHandledException(
                'This Consumer Report does not have a Report Response.'
            );
        }
        
        PageReference xmlPage =
            new PageReference(
                '/apex/forseva1__ReportResponseData'
            );
        
        xmlPage.getParameters().put(
            'id',
            String.valueOf(
                report.forseva1__Report_Response__c
            )
        );
        
        xmlPage.getParameters().put(
            'format',
            'xml'
        );
        
        Blob xmlContent;
        
        try {
            xmlContent =
                xmlPage.getContent();
        } catch (Exception error) {
            throw new AuraHandledException(
                'XML could not be generated: ' +
                error.getMessage()
            );
        }
        
        if (
            xmlContent == null ||
            xmlContent.size() == 0
        ) {
            throw new AuraHandledException(
                'The generated XML was empty.'
            );
        }
        
        XmlDownloadResult result =
            new XmlDownloadResult();
        
        result.fileName =
            report.Name + '.xml';
        
        result.base64Content =
            EncodingUtil.base64Encode(
                xmlContent
            );
        
        result.contentSize =
            xmlContent.size();
        
        return result;
    }
    
}